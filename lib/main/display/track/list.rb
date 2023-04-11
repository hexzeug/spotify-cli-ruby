# frozen_string_literal: true

module Main
  module Display
    module Track
      class List
        def initialize(screen_message)
          @screen_message = screen_message
          @title = screen_message.content[:title]
          tracks = screen_message.content[:tracks]
          register_context(tracks)
          @table = generate_table(tracks)
        end

        def context_updated
          @screen_message.touch
        end

        def delete
          Context.unhook(self)
        end

        def generate(max_width)
          <<~TEXT
              $*#{@title}$*
            #{@table.generate(max_width)}
          TEXT
        end

        private

        def register_context(tracks)
          Context.register(tracks.map { |track| track[:uri] })
          Context.register(
            tracks.flat_map do |track|
              track[:artists].map { |artist| artist[:uri] }
            end
          )
          Context.register(tracks.map { |track| track[:album][:uri] })
        end

        def generate_table(tracks)
          table = Display::Table.new(
            {
              title: '#',
              width: 3,
              align: :right
            },
            {
              title: 'Title',
              width: { fraction: 4, min: 10 },
              overflow: :tripple_dot
            },
            {
              title: 'Artists',
              width: { fraction: 2 },
              overflow: :tripple_dot
            },
            {
              title: 'Album',
              width: { fraction: 3 },
              overflow: :tripple_dot
            },
            gap: 2
          )
          tracks.each_with_index do |track, i|
            track_name = track[:name].gsub('$', '$$')
            track_hook = Context.hook(track[:uri], self)
            album = track[:album]
            album_name = album[:name].gsub('$', '$$')
            album_hook = Context.hook(album[:uri], self)
            artists = track[:artists]
            artist_names = artists.map do |artist|
              artist[:name].gsub('$', '$$')
            end
            artist_hooks = artists.map do |artist|
              Context.hook(artist[:uri], self)
            end
            table.add_row(
              (i + 1).to_s,
              "#{track_name} $%(#{track_hook})$%",
              artist_names.zip(artist_hooks).map do |artist_name, artist_hook|
                "#{artist_name} $%(#{artist_hook})$%"
              end.join(', '),
              "#{album_name} $%(#{album_hook})$%"
            )
          end
          table
        end
      end
    end
  end
end
