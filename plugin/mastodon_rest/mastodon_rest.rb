Plugin.create(:mastodon_rest) do
  @tags = {}                    # world_hash => handler_tag

  subscribe(:mastodon_worlds__add).each do |new_world|
    [ new_world.rest.user,
      new_world.rest.direct
    ].each { |stream| generate_stream(stream, tag: tag_of(new_world)) }
    new_world.get_lists.next { |lists|
      lists.each do |l|
        generate_stream(new_world.rest.list(list_id: l[:id].to_i, title: l[:title]), tag: tag_of(new_world))
      end
    }.terminate(_('Mastodon: リスト取得時にエラーが発生しました'))
  end

  subscribe(:mastodon_worlds__delete).each do |lost_world|
    detach(tag_of(lost_world))
  end

  subscribe(:mastodon_servers__add).each do |server|
    generate_stream(server.rest.public,                         tag: tag_of(server))
    generate_stream(server.rest.public_local,                   tag: tag_of(server))
    generate_stream(server.rest.public(only_media: true),       tag: tag_of(server))
    generate_stream(server.rest.public_local(only_media: true), tag: tag_of(server))
  end

  subscribe(:mastodon_servers__delete).each do |lost_server|
    detach(tag_of(lost_server))
  end

  def generate_stream(connection, tag:)
    generate(:extract_receive_message, connection.datasource_slug, tags: [tag]) do |stream_input|
      Delayer::Deferred.next do
        wait_count = Float::INFINITY
        loop do
          wait_count += 1
          if wait_count >= UserConfig[:mastodon_rest_interval]
            wait_count = 0
            (+query(connection))&.yield_self(&stream_input.method(:bulk_add))
          end
          +Delayer::Deferred.sleep(60)
        end
      rescue Pluggaloid::NoReceiverError
        # ignore
      end.trap do |err|
        Delayer.new { raise err }
      end
    end
  end

  def query(connection)
    Plugin::Mastodon::API.call(:get, connection.uri.host, connection.uri.path, connection.token, limit: 200, **connection.params).next { |api_response|
      Plugin::Mastodon::Status.bulk_build(connection.server, api_response.value)
    }.terminate(_('Mastodon: %{title}取得時にエラーが発生しました') % {title: connection.title})
      .trap{ nil }
  end

  def tag_of(world_or_server)
    @tags[world_or_server.hash] ||= handler_tag()
  end
end
