# frozen_string_literal: true

module Main
end

require_relative 'spotify'
require_relative 'command'
require_relative 'ui'

require_relative 'main/def_cmd'

Spotify::Auth::Token.load(save: true)

Main::DefCmd.create
UI.returns { |str| Main::DefCmd.execute(str) }
UI.errors do
  Spotify::Auth::Token.save
  false
end
UI.start_loop

Spotify::Auth::Token.save(save: true)