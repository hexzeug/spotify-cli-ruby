# frozen_string_literal: true

module Main
  module Display
    module Names
      def track(track)
        ctx_id = Context.hook(track[:uri], self)
        name = escape(track[:name])
        name += ' $! E $!' if track[:explicit]
        name += " $%(#{ctx_id})$%" unless ctx_id.nil?
        name
      end

      def artist(artist)
        ctx_id = Context.hook(artist[:uri], self)
        name = escape(artist[:name])
        name += " $%(#{ctx_id})$%" unless ctx_id.nil?
        name
      end

      def artists(artists)
        artists.map { |artist| artist(artist) }.join(', ')
      end

      def album(album)
        ctx_id = Context.hook(album[:uri], self)
        name = escape(album[:name])
        name += " $%(#{ctx_id})$%" unless ctx_id.nil?
        name
      end

      def user(user)
        ctx_id = Context.hook(user[:uri], self)
        name = escape(user[:display_name])
        name += " $%(#{ctx_id})$%" unless ctx_id.nil?
        name
      end

      def playlist(playlist)
        ctx_id = Context.hook(playlist[:uri], self)
        name = escape(playlist[:name])
        name += " $%(#{ctx_id})$%" unless ctx_id.nil?
        name
      end

      def escape(str)
        str.gsub('$', '$$')
      end
    end
  end
end
