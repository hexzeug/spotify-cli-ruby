# frozen_string_literal: true

require 'securerandom'

module Spotify
  module Auth
    APP_ID = '4388096316894b88a147b53559d0c14a'
    APP_SECRET = '77f2373853974699824602358ecdf9bd'

    PROMPT_URL = 'https://accounts.spotify.com/authorize/'
    REDIRECT_URL = 'http://localhost:8888/callback/'
    TOKEN_URL = 'https://accounts.spotify.com/api/token/'

    class << self
      LOGIN_TIMEOUT_SEC = 5 * 60

      ##
      # @param & [Proc] optional callback of returned [Spotify::Promise]
      # @return [Spotify::Promise]
      #
      # @raise [Prompt::OpenPromptError]
      # @raise [CodeServer::OpenServerError]
      # @raise [CodeServer::CodeDeniedError]
      # @raise [TokenFetcher::TokenFetchError] and subclasses
      # @raise [TokenFetcher::ParseError]
      # @raise [TokenFetcher::TokenDeniedError]
      # @raise [Token::TokenParseError] and subclasses
      # @raise [Token::MalformedTokenError]
      # @raise [Token::MissingAccessTokenError]
      # @raise [Token::MissingExpirationTimeError]
      # @raise [Token::MissingRefreshTokenError]
      def login(&)
        promise = Spotify::Promise.new(&)

        timeout_thread = Thread.new do
          Thread.current.name = 'login/timeout'
          sleep LOGIN_TIMEOUT_SEC
          CodeServer.stop
        end

        state = SecureRandom.hex 16
        CodeServer.start(state) do |code|
          token = TokenFetcher.fetch(code:)
          Token.set(token)
          timeout_thread.kill
          Thread.new do
            Thread.current.name = 'login/return'
            promise.resolve
          end
        end.error do |error|
          timeout_thread.kill
          promise.resolve_error(error)
        end
        Prompt.open(state)
        promise.on_cancel do
          timeout_thread.kill
          CodeServer.stop
        end
      rescue CodeServer::OpenServerError => e
        timeout_thread.kill
        promise.resolve_error(e)
      rescue Prompt::OpenPromptError => e
        CodeServer.stop
        timeout_thread.kill
        promise.resolve_error(e)
      end
    end
  end
end

require_relative 'auth/token'
require_relative 'auth/prompt'
require_relative 'auth/code_server'
require_relative 'auth/token_fetcher'
