# frozen_string_literal: true

require 'webrick'

module Spotify
  module Auth
    module CodeServer
      ##
      # raised by CodeServer.start when the system call to open the socket fails
      class OpenServerError < SpotifyError
        attr_reader :system_call_error

        def initialize(system_call_error)
          super
          @system_call_error = system_call_error
        end
      end

      ##
      # raised when authorize endpoint denies request for authorization code
      # for possible error_str see https://www.rfc-editor.org/rfc/rfc6749#section-4.1.2.1
      class CodeDeniedError < SpotifyError
        attr_reader :error_str

        def initialize(error_str)
          super()
          @error_str = error_str
        end
      end

      class << self
        include WEBrick

        HTTP_SERVER_CONFIG = Config::HTTP.update(Logger: BasicLog.new(nil, 0))
        HOST = URI(Spotify::Auth::REDIRECT_URL)

        ##
        # does nothing if no block is given
        #
        # @param state [String] check requests for matching
        #   states before handling
        #
        # @return [Promise]
        # @return [String] code
        #
        # @raise [OpenCodeServerError]
        # @raise [CodeDeniedError]
        # @raise [StandardError] every exception raised in block
        def start(state, &)
          return unless block_given?

          @state = state
          @promise = Spotify::Promise.new(&).on_cancel { stop }
          return @promise if @server

          begin
            @server = TCPServer.new(HOST.hostname, HOST.port)
          rescue SystemCallError => e
            stop
            @promise.fail(OpenServerError.new(e))
            return @promise
          end
          Thread.new do
            Thread.current.name = 'code-server/loop'
            server_loop
          end
          @promise
        end

        def stop
          @server&.close
          @server = nil
          @state = nil
          @promise = nil
        end

        private

        def server_loop
          while @server && !@server.closed?
            Thread.new(@server.accept) do |socket|
              handle_connection socket
              socket.close
            end
          end
        rescue IOError
          @server&.close
          @server = nil
        end

        def handle_connection(socket)
          Thread.current.name =
            "code-server/client(#{socket.peeraddr[2]}:#{socket.peeraddr[1]})"
          req = HTTPRequest.new HTTP_SERVER_CONFIG
          res = HTTPResponse.new HTTP_SERVER_CONFIG
          begin
            req.parse socket
          rescue HTTPStatus::BadRequest
            generate_response res, MalformedRequest.new
          rescue HTTPStatus::EOFError
            return # socket was probably closed -> don't respond
          else
            handle_request req, res
          end

          res.keep_alive = false
          res.setup_header
          res.header.delete 'server' # is generated by HTTPResponse#setup_header
          begin
            res.send_header socket
            res.send_body socket
          rescue StandardError
            # sending response failed -> ignore it
          end
        end

        def handle_request(req, res)
          unless @state && req.path == HOST.path
            generate_response(res, NoContent.new)
            return
          end
          if req.query['state'] != @state
            generate_response(res, BadState.new(req.query['state']))
            return
          end
          unless req.query.key?('code')
            on_code_denied(res, req.query['error'])
            return
          end
          on_code_received(res, req.query['code'])
        end

        def on_code_denied(res, error_str)
          promise = @promise
          stop
          report_error(res, promise, CodeDeniedError.new(error_str))
        end

        def on_code_received(res, code)
          promise = @promise
          stop
          old_thread_name = Thread.current.name
          Thread.current.name = 'code-server/return'
          begin
            promise.resolve code
          rescue StandardError => e
            Thread.current.name = old_thread_name
            report_error(res, promise, e)
          else
            generate_response res
          end
        end

        def report_error(res, promise, error)
          Thread.new do
            Thread.current.name = 'code-server/return/error'
            promise.fail(error)
          end
          generate_response res, error
        end

        def generate_response(res, error = nil)
          # @todo generate prettier response pages
          res.status = HTTPStatus::RC_BAD_REQUEST # default
          case error
          when nil
            res.status = HTTPStatus::RC_OK
            res.body = 'success'
          when MalformedRequest
            res.body = 'malformed request'
          when NoContent
            res.status = HTTPStatus::RC_NO_CONTENT
          when BadState
            res.body =
              error.state? ? "wrong state '#{error.state}'" : 'missing state'
          when CodeDeniedError
            # @todo prettier response: parse error_str from https://www.rfc-editor.org/rfc/rfc6749#section-4.1.2.1
            res.body = "access denied. #{error.error_str}"
          when Auth::TokenFetcher::TokenDeniedError
            # @todo prettier response: parse error_str form https://www.rfc-editor.org/rfc/rfc6749#section-5.2
            res.body = "token denied. #{error.error_str}"
          else
            res.status = HTTPStatus::RC_INTERNAL_SERVER_ERROR
            res.body = "internal error. (#{error.class})"
          end
        end

        # superclass bundling all internal server errors
        # that only occur internally
        class InternalError < StandardError
        end

        # internal error
        # used for malformed http requests
        class MalformedRequest < InternalError
        end

        # internal error
        # used for other paths then /callback/
        # or when server isn't listening for requests
        class NoContent < InternalError
        end

        # internal error
        # used for wrong or missing state
        class BadState < InternalError
          attr_reader :state

          def initialize(state)
            super()
            @state = state
          end

          def state?
            @state ? true : false
          end
        end
      end
    end
  end
end
