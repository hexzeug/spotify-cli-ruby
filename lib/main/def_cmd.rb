# frozen_string_literal: true

module Main
  module DefCmd
    class << self
      ##
      # @return [Command::Dispatcher]
      def create
        @dispatcher = Command::Dispatcher.new
        Exit.new(@dispatcher)
        Echo.new(@dispatcher)
        Account.new(@dispatcher)
        TopItems.new(@dispatcher)
        Search.new(@dispatcher)
        Play.new(@dispatcher)
        Details.new(@dispatcher)
      end

      def execute(str)
        @dispatcher.execute(str)
      rescue Command::CommandError => e
        raise UI::Error, "$r#{e.message}"
      end

      def suggest(str)
        @dispatcher.suggest(str)
      rescue Command::CommandError => e
        raise UI::Error, "$r#{e.message}"
      end
    end
  end
end

require_relative 'def_cmd/exit'
require_relative 'def_cmd/echo'
require_relative 'def_cmd/account'
require_relative 'def_cmd/top_items'
require_relative 'def_cmd/search'
require_relative 'def_cmd/play'
require_relative 'def_cmd/details'
