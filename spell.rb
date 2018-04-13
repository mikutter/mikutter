# coding: utf-8

Plugin.create(:worldon) do
  pm = Plugin::Worldon

  # command
  custom_postable = Proc.new do |opt|
    world, = Plugin.filtering(:world_current, nil)
    [:worldon, :portal].include?(world.class.slug) && opt.widget.editable?
  end

  def visibility2select(s)
    case s
    when "public"
      :"1public"
    when "unlisted"
      :"2unlisted"
    when "private"
      :"3private"
    when "direct"
      :"4direct"
    else
      nil
    end
  end

  def select2visibility(s)
    case s
    when :"1public"
      "public"
    when :"2unlisted"
      "unlisted"
    when :"3private"
      "private"
    when :"4direct"
      "direct"
    else
      nil
    end
  end

  command(
    :worldon_custom_post,
    name: 'カスタム投稿',
    condition: custom_postable,
    visible: true,
    icon: Skin['post.png'],
    role: :postbox
  ) do |opt|
    world, = Plugin.filtering(:world_current, nil)

    i_postbox = opt.widget
    postbox, = Plugin.filtering(:gui_get_gtk_widget, i_postbox)
    body = postbox.widget_post.buffer.text
    reply_to = postbox.worldon_get_reply_to

    dialog "カスタム投稿" do
      # オプションを並べる
      multitext "CW警告文", :spoiler_text
      self[:body] = body
      multitext "本文", :body
      self[:sensitive] = world.account.source.sensitive
      boolean "閲覧注意", :sensitive

      visibility_default = world.account.source.privacy
      if reply_to.is_a?(pm::Status) && reply_to.visibility == "direct"
        # 返信先がDMの場合はデフォルトでDMにする。但し編集はできるようにするため、この時点でデフォルト値を代入するのみ。
        visibility_default = "direct"
      end
      self[:visibility] = visibility2select(visibility_default)
      select "公開範囲", :visibility do
        option :"1public", "公開"
        option :"2unlisted", "未収載"
        option :"3private", "非公開"
        option :"4direct", "ダイレクト"
      end

      # mikutter-uwm-hommageの設定を勝手に持ってくる
      dirs = 10.times.map { |i|
        UserConfig["galary_dir#{i + 1}".to_sym]
      }.compact.select { |str|
        !str.empty?
      }.to_a

      fileselect "添付メディア1", :media1, shortcuts: dirs
      fileselect "添付メディア2", :media2, shortcuts: dirs
      fileselect "添付メディア3", :media3, shortcuts: dirs
      fileselect "添付メディア4", :media4, shortcuts: dirs
    end.next do |result|
      # 投稿
      # まず画像をアップロード
      media_ids = []
      media_urls = []
      (1..4).each do |i|
        if result[:"media#{i}"]
          path = Pathname(result[:"media#{i}"])
          hash = pm::API.call(:post, world.domain, '/api/v1/media', world.access_token, [:file], file: path)
          media_ids << hash[:id].to_i
          media_urls << hash[:text_url]
        end
      end
      # 画像がアップロードできたらcompose spellを起動
      opts = {
        body: result[:body]
      }
      if !media_ids.empty?
        opts[:media_ids] = media_ids
      end
      if !result[:spoiler_text].empty?
        opts[:spoiler_text] = result[:spoiler_text]
      end
      opts[:sensitive] = result[:sensitive]
      opts[:visibility] = select2visibility(result[:visibility])
      compose(world, reply_to, **opts)

      if Gtk::PostBox.list[0] != postbox
        postbox.destroy
      else
        postbox.widget_post.buffer.text = ''
      end
    end
  end


  # spell系

  # 投稿
  defspell(:compose, :worldon) do |world, body:, **opts|
    if opts[:visibility].nil?
      opts.delete :visibility
    else
      opts[:visibility] = opts[:visibility].to_s
    end

    if opts[:sensitive].nil? && opts[:media_ids].nil? && opts[:spoiler_text].nil?
      opts[:sensitive] = false;
    end

    hash = world.post(body, opts)
    if hash.nil?
      warn "投稿に失敗したかもしれません"
      pp hash if Mopt.error_level >= 2
      $stdout.flush
      nil
    else
      new_status = pm::Status.build(world.domain, [hash]).first
      Plugin.call(:posted, world, [new_status])
      Plugin.call(:update, world, [new_status])
      new_status
    end
  end

  memoize def media_tmp_dir
    path = Pathname(Environment::TMPDIR) / 'worldon' / 'media'
    FileUtils.mkdir_p(path.to_s)
    path
  end

  defspell(:compose, :worldon, :photo) do |world, photo, body:, **opts|
    photo.download.next{|photo|
      ext = photo.uri.path.split('.').last || 'png'
      tmp_name = Digest::MD5.hexdigest(photo.uri.to_s) + ".#{ext}"
      tmp_path = media_tmp_dir / tmp_name
      file_put_contents(tmp_path, photo.blob)
      hash = pm::API.call(:post, world.domain, '/api/v1/media', world.access_token, [:file], file: tmp_path.to_s)
      if hash
        media_id = hash[:id]
        compose(world, body: body, media_ids: [media_id], **opts)
      end
    }
  end

  defspell(:compose, :worldon, :worldon_status) do |world, status, body:, **opts|
    if opts[:visibility].nil?
      opts.delete :visibility
      if status.visibility == "direct"
        # 返信先がDMの場合はデフォルトでDMにする。但し呼び出し元が明示的に指定してきた場合はそちらを尊重する。
        opts[:visibility] = "direct"
      end
    else
      opts[:visibility] = opts[:visibility].to_s
    end
    if opts[:sensitive].nil? && opts[:media_ids].nil? && opts[:spoiler_text].nil?
      opts[:sensitive] = false;
    end

    status_id = status.id
    _status_id = pm::API.get_local_status_id(world, status)
    if _status_id
      status_id = _status_id
      opts[:in_reply_to_id] = status_id
      hash = world.post(body, opts)
      if hash.nil?
        warn "投稿に失敗したかもしれません"
        pp hash if Mopt.error_level >= 2
        $stdout.flush
        nil
      else
        new_status = pm::Status.build(world.domain, [hash]).first
        Plugin.call(:posted, world, [new_status])
        Plugin.call(:update, world, [new_status])
        new_status
      end
    else
      warn "返信先Statusが#{world.domain}内に見つかりませんでした：#{status.url}"
      nil
    end
  end

  defspell(:destroy, :worldon, :worldon_status, condition: -> (world, status) {
    world.account.acct == status.actual_status.account.acct
  }) do |world, status|
    status_id = pm::API.get_local_status_id(world, status.actual_status)
    if status_id
      ret = pm::API.call(:delete, world.domain, "/api/v1/statuses/#{status_id}", world.access_token)
      Plugin.call(:destroyed, status.actual_status)
      status.actual_status
    end
  end

  # ふぁぼ
  defspell(:favorite, :worldon, :worldon_status,
           condition: -> (world, status) { !status.actual_status.favorite?(world) }
          ) do |world, status|
    Thread.new {
      status_id = pm::API.get_local_status_id(world, status.actual_status)
      if status_id
        Plugin.call(:before_favorite, world, world.account, status)
        ret = pm::API.call(:post, world.domain, '/api/v1/statuses/' + status_id.to_s + '/favourite', world.access_token)
        if ret.nil? || ret[:error]
          Plugin.call(:fail_favorite, world, world.account, status)
        else
          status.actual_status.favourited = true
          status.actual_status.favorite_accts << world.account.acct
          Plugin.call(:favorite, world, world.account, status)
        end
      end
    }
  end

  defspell(:favorited, :worldon, :worldon_status,
           condition: -> (world, status) { status.actual_status.favorite?(world) }
          ) do |world, status|
    Delayer::Deferred.new.next {
      status.actual_status.favorite?(world)
    }
  end

  defspell(:unfavorite, :worldon, :worldon_status, condition: -> (world, status) { status.favorite?(world) }) do |world, status|
    Thread.new {
      status_id = pm::API.get_local_status_id(world, status.actual_status)
      if status_id
        ret = pm::API.call(:post, world.domain, '/api/v1/statuses/' + status_id.to_s + '/unfavourite', world.access_token)
        if ret.nil? || ret[:error]
          warn "[worldon] failed to unfavourite: #{ret}"
        else
          status.actual_status.favourited = false
          status.actual_status.favorite_accts.delete(world.account.acct)
          Plugin.call(:favorite, world, world.account, status)
        end
        status.actual_status
      end
    }
  end

  # ブースト
  defspell(:share, :worldon, :worldon_status,
           condition: -> (world, status) { status.actual_status.rebloggable?(world) }
          ) do |world, status|
    world.reblog(status.actual_status).next{|shared|
      Plugin.call(:posted, world, [shared])
      Plugin.call(:update, world, [shared])
    }
  end

  defspell(:shared, :worldon, :worldon_status,
           condition: -> (world, status) { status.actual_status.shared?(world) }
          ) do |world, status|
    Delayer::Deferred.new.next {
      status.actual_status.shared?(world)
    }
  end

  defspell(:destroy_share, :worldon, :worldon_status, condition: -> (world, status) { status.actual_status.shared?(world) }) do |world, status|
    Thread.new {
      status_id = pm::API.get_local_status_id(world, status.actual_status)
      if status_id
        ret = pm::API.call(:post, world.domain, '/api/v1/statuses/' + status_id.to_s + '/unreblog', world.access_token)
        reblog = nil
        if ret.nil? || ret[:error]
          warn "[worldon] failed to unreblog: #{ret}"
        else
          status.actual_status.reblogged = false
          reblog = status.actual_status.retweeted_statuses.select{|s| s.account.acct == world.user_obj.acct }.first
          status.actual_status.reblog_status_uris.delete_if {|pair| pair[:acct] == world.user_obj.acct }
          if reblog
            Plugin.call(:destroyed, [reblog])
          end
        end
        reblog
      end
    }
  end

  # プロフィール更新系
  update_profile_block = Proc.new do |world, **opts|
    world.update_profile(**opts)
  end

  defspell(:update_profile, :worldon, &update_profile_block)
  defspell(:update_profile_name, :worldon, &update_profile_block)
  defspell(:update_profile_biography, :worldon, &update_profile_block)
  defspell(:update_profile_icon, :worldon, :photo) do |world, photo|
    update_profile_block.call(world, icon: photo)
  end
  defspell(:update_profile_header, :worldon, :photo) do |world, photo|
    update_profile_block.call(world, header: photo)
  end
end
