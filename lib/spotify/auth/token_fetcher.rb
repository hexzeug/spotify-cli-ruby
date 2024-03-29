# frozen_string_literal: true

require 'uri'
require 'base64'
require 'json'

module Spotify
  module Auth
    module TokenFetcher
      ##
      # superclass for token fetch errors
      class TokenFetchError < SpotifyError
      end

      ##
      # raised when token endpoint return not parsable body
      class ParseError < TokenFetchError
      end

      ##
      # raised when token endpoint denies to request new / refresh token
      # for possible error_str see https://www.rfc-editor.org/rfc/rfc6749#section-5.2
      class TokenDeniedError < TokenFetchError
        attr_reader :error_str, :error_description

        def initialize(error_str, error_description)
          super()
          @error_str = error_str
          @error_description = error_description
        end
      end

      class << self
        ENDPOINT_URI = URI(Auth::TOKEN_URL).freeze
        HEADER = {
          'Content-Type': 'application/x-www-form-urlencoded',
          Authorization:
                "Basic #{Base64.strict_encode64(
                  "#{Auth::APP_ID}:#{Auth::APP_SECRET}"
                )}"
        }.freeze
        CODE_BODY = {
          grant_type: 'authorization_code',
          redirect_uri: Auth::REDIRECT_URL
        }.freeze
        REFRESH_BODY = {
          grant_type: 'refresh_token'
        }.freeze

        ##
        # fetches new access token
        # using code when given
        # or refresh token otherwise
        #
        # @param code [String] *(optional)*
        #
        # @return [Hash] token
        # @return [Promise] *(when called with block)*
        #
        # @raise [Auth::Token::NoTokenError]
        # @raise [Request::RequestError]
        # @raise [TokenFetchError] superclass
        # @raise [ParseError]
        # @raise [TokenDeniedError]
        def fetch(code: nil, &)
          body = URI.encode_www_form(
            if code.nil?
              REFRESH_BODY.merge(refresh_token: Auth::Token.refresh_token)
            else
              CODE_BODY.merge(code:)
            end
          )

          unless block_given?
            return receive(
              Spotify::Request.http(ENDPOINT_URI, :post, HEADER, body)
            )
          end

          promise = Spotify::Promise.new(&)
          request_promise =
            Spotify::Request.http(
              ENDPOINT_URI,
              :post,
              HEADER,
              body
            ) do |res|
              token = receive(res)
            rescue TokenFetchError => e
              promise.fail(e)
            else
              promise.resolve(token)
            end.error do |error|
              promise.fail(error)
            end
          promise.on_cancel { request_promise.cancel }
        end

        private

        def receive(res)
          body = JSON.parse(res.body, symbolize_names: true)
          if body.key?(:error)
            raise TokenDeniedError.new(
              body[:error],
              body[:error_description]
            )
          end

          body
        rescue JSON::JSONError
          raise ParseError
        end
      end
    end
  end
end
