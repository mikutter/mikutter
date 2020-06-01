Plugin.create(:mastodon_rest) do
  @tags = {}                    # world_hash => handler_tag

  subscribe(:mastodon_worlds__add).each do |new_world|
    tag = @tags[new_world.hash] ||= handler_tag()
    [ new_world.rest.user,
      new_world.rest.direct
    ].each { |stream| generate_stream(stream, tag: tag) }
    new_world.get_lists.next { |lists|
      lists.each do |l|
        generate_stream(new_world.rest.list(list_id: l[:id].to_i, title: l[:title]), tag: tag)
      end
    }.terminate(_('Mastodon: リスト取得時にエラーが発生しました'))
  end

  subscribe(:mastodon_worlds__delete).each do |lost_world|
    detach(@tags[lost_world.hash])
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
        error err
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
end
