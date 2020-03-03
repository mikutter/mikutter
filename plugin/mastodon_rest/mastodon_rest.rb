Plugin.create(:mastodon_rest) do
  subscribe(:mastodon_worlds__add).each do |world|
    wait_count = 0
    polling = -> do
      next unless collect(:mastodon_worlds).include?(world)
      wait_count += 1
      if wait_count >= UserConfig[:mastodon_rest_interval]
        wait_count = 0
        query_all(world)
      end
      Delayer.new(delay: 60, &polling)
    end
    polling.call
  end

  def query_all(world)
    [ world.rest.user,
      world.rest.direct
    ].each do |connection|
      query(connection)
    end
    world.get_lists.next { |lists|
      lists.each do |l|
        query(world.rest.list(list_id: l[:id].to_i, title: l[:title]))
      end
    }.terminate(_('Mastodon: リスト取得時にエラーが発生しました'))
  end

  def query(connection)
    if subscribe?(:extract_receive_message, connection.datasource_slug)
      Plugin::Mastodon::API.call(:get, connection.uri.host, connection.uri.path, connection.token, limit: 200, **connection.params).next do |api_response|
        messages = Plugin::Mastodon::Status.build(connection.uri.host, api_response.value)
        Plugin.call(:extract_receive_message, connection.datasource_slug, messages)
      end.terminate(_('Mastodon: %{title}取得時にエラーが発生しました') % {title: connection.title})
    end
  end
end
