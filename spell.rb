Plugin.create(:worldon) do
  # spell系

  # 投稿
  defspell(:compose, :worldon_for_mastodon, condition: -> (world) { true }) do |world, body:, **opts|
    # TODO: PostBoxから渡ってくるoptsを適当に変換する
    if opts[:visibility].nil?
      opts.delete :visibility
    end
    world.post(body, opts)
  end

  defspell(:compose, :worldon_for_mastodon, :worldon_status,
           condition: -> (world, status) { true }
          ) do |world, status, body:, **opts|
    # TODO: PostBoxから渡ってくるoptsを適当に変換する
    if opts[:visibility].nil?
      opts.delete :visibility
    end
    status_id = status.id
    _status_id = PM::API.get_local_status_id(world, status)
    if !_status_id.nil?
      status_id = _status_id
      opts[:in_reply_to_id] = status_id
      hash = world.post(body, opts)
      if hash.nil?
        warn "投稿に失敗したかもしれません"
        pp hash
        $stdout.flush
        nil
      else
        new_status = PM::Status.build(world.domain, [hash]).first
        Plugin.call(:posted, world, [new_status])
        Plugin.call(:update, world, [new_status])
        new_status
      end
    else
      warn "返信先Statusが#{world.domain}内に見つかりませんでした：#{status.url}"
      nil
    end
  end

  # ふぁぼ
  defevent :worldon_favorite, prototype: [PM::World, PM::Status]

  # ふぁぼる
  on_worldon_favorite do |world, status|
    # TODO: guiなどの他plugin向け通知イベントの調査
    status_id = PM::API.get_local_status_id(world, status.actual_status)
    if !status_id.nil?
      Plugin.call(:before_favorite, world, world.account, status)
      ret = PM::API.call(:post, world.domain, '/api/v1/statuses/' + status_id.to_s + '/favourite', world.access_token)
      if ret.nil? || ret[:error]
        Plugin.call(:fail_favorite, world, world.account, status)
      else
        status.actual_status.favourited = true
        Plugin.call(:favorite, world, world.account, status)
      end
    end
  end

  defspell(:favorite, :worldon_for_mastodon, :worldon_status,
           condition: -> (world, status) { !status.actual_status.favorite? } # TODO: favorite?の引数にworldを取って正しく判定できるようにする
          ) do |world, status|
    Plugin.call(:worldon_favorite, world, status.actual_status)
  end

  defspell(:favorited, :worldon_for_mastodon, :worldon_status,
           condition: -> (world, status) { status.actual_status.favorite? } # TODO: worldを使って正しく判定する
          ) do |world, status|
    Delayer::Deferred.new.next {
      status.actual_status.favorite? # TODO: 何を返せばいい？
    }
  end

  # ブーストイベント
  defevent :worldon_share, prototype: [PM::World, PM::Status]

  # ブースト
  on_worldon_share do |world, status|
    world.reblog(status).next{|shared|
      Plugin.call(:posted, world, [shared])
      Plugin.call(:update, world, [shared])
    }
  end

  defspell(:share, :worldon_for_mastodon, :worldon_status,
           condition: -> (world, status) { !status.actual_status.shared? } # TODO: shared?の引数にworldを取って正しく判定できるようにする
          ) do |world, status|
    world.reblog status
  end

  defspell(:shared, :worldon_for_mastodon, :worldon_status,
           condition: -> (world, status) { status.actual_status.shared? } # TODO: worldを使って正しく判定する
          ) do |world, status|
    Delayer::Deferred.new.next {
      status.actual_status.shared? # TODO: 何を返せばいい？
    }
  end
end
