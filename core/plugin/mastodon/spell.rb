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

      settings "添付メディア" do
        # mikutter-uwm-hommageの設定を勝手に持ってくる
        dirs = 10.times.map { |i|
          UserConfig["galary_dir#{i + 1}".to_sym]
        }.compact.select { |str|
          !str.empty?
        }.to_a

        fileselect "", :media1, shortcuts: dirs, use_preview: true
        fileselect "", :media2, shortcuts: dirs, use_preview: true
        fileselect "", :media3, shortcuts: dirs, use_preview: true
        fileselect "", :media4, shortcuts: dirs, use_preview: true
      end

      settings "投票を受付ける" do
        input "1", :poll_options1
        input "2", :poll_options2
        input "3", :poll_options3
        input "4", :poll_options4
        select "投票受付期間", :poll_expires_in do
          option :min5, "5分"
          option :hour, "1時間"
          option :day, "1日"
          option :week, "1週間"
          option :month, "1ヶ月"
        end
        boolean "複数選択可にする", :poll_multiple
        boolean "終了するまで結果を表示しない", :poll_hide_totals
      end
    end.next do |result|
      # 投稿
      # まず画像をアップロード
      media_ids = []
      media_urls = []
      (1..4).each do |i|
        if result[:"media#{i}"]
          path = Pathname(result[:"media#{i}"])
          hash = pm::API.call(:post, world.domain, '/api/v1/media', world.access_token, file: path)
          if hash.value && hash[:error].nil?
            media_ids << hash[:id].to_i
            media_urls << hash[:text_url]
          else
            Deferred.fail(hash[:error] ? hash[:error] : 'メディアのアップロードに失敗しました')
            next
          end
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

      if (1..4).any?{|i| result[:"poll_options#{i}"] }
        opts[:poll] = Hash.new
        opts[:poll][:expires_in] = case result[:poll_expires_in]
                                   when :min5
                                     5 * 60 + 1 # validation error回避のための+1
                                   when :hour
                                     60 * 60
                                   when :day
                                     24 * 60 * 60
                                   when :week
                                     7 * 24 * 60 * 60
                                   when :month
                                     (Date.today.next_month - Date.today).to_i * 24 * 60 * 60 - 1 # validation error回避のための-1
                                   end
        opts[:poll][:multiple] = !!result[:poll_multiple]
        opts[:poll][:hide_totals] = !!result[:poll_hide_totals]
        opts[:poll][:options] = (1..4).map{|i| result[:"poll_options#{i}"] }.compact
      end

      compose(world, reply_to, **opts)

      if Gtk::PostBox.list[0] != postbox
        postbox.destroy
      else
        postbox.widget_post.buffer.text = ''
      end
    end
  end

  command(:worldon_follow_user, name: 'フォローする', visible: true, role: :timeline,
          condition: lambda { |opt|
            world, = Plugin.filtering(:world_current, nil)
            opt.messages.any? { |m|
              follow?(world, m.user)
            }
          }) do |opt|
    world, = Plugin.filtering(:world_current, nil)
    next unless world

    opt.messages.map { |m|
      m.user
    }.each { |user|
      follow(world, user)
    }
  end

  command(:worldon_unfollow_user, name: 'フォロー解除', visible: true, role: :timeline,
          condition: lambda { |opt|
            world, = Plugin.filtering(:world_current, nil)
            opt.messages.any? { |m|
              unfollow?(world, m.user)
            }
          }) do |opt|
    world, = Plugin.filtering(:world_current, nil)
    next unless world

    opt.messages.map { |m|
      m.user
    }.each { |user|
      unfollow(world, user)
    }
  end

  command(:worldon_mute_user, name: 'ミュートする', visible: true, role: :timeline,
          condition: lambda { |opt|
            world, = Plugin.filtering(:world_current, nil)
            opt.messages.any? { |m| mute_user?(world, m.user) }
          }) do |opt|
    world, = Plugin.filtering(:world_current, nil)
    next unless world
    users = opt.messages.map { |m| m.user }.uniq
    dialog "ミュートする" do
      label "以下のユーザーをミュートしますか？"
      users.each { |user|
        link user
      }
    end.next do
      users.each { |user|
        mute_user(world, user)
      }
    end
  end

  command(:worldon_block_user, name: 'ブロックする', visible: true, role: :timeline,
          condition: lambda { |opt|
            world, = Plugin.filtering(:world_current, nil)
            opt.messages.any? { |m| block_user?(world, m.user) }
          }) do |opt|
    world, = Plugin.filtering(:world_current, nil)
    next unless world
    users = opt.messages.map { |m| m.user }.uniq
    dialog "ブロックする" do
      label "以下のユーザーをブロックしますか？"
      users.each { |user|
        link user
      }
    end.next do
      users.each { |user|
        block_user(world, user)
      }
    end
  end

  command(:worldon_report_status, name: '通報する', visible: true, role: :timeline,
          condition: lambda { |opt|
            world, = Plugin.filtering(:world_current, nil)
            opt.messages.any? { |m| report_for_spam?(world, m) }
          }) do |opt|
    world, = Plugin.filtering(:world_current, nil)
    next unless world
    dialog "通報する" do
      error_msg = nil
      while true
        label "以下のトゥートを #{world.domain} サーバーの管理者に通報しますか？"
        opt.messages.each { |message|
          link message
        }
        multitext "コメント（1000文字以内） ※必須", :comment
        label error_msg if error_msg

        result = await_input
        error_msg = "コメントを入力してください。" if (result[:comment].nil? || result[:comment].empty?)
        error_msg = "コメントが長すぎます（#{result[:comment].to_s.size}文字）" if result[:comment].to_s.size > 1000
        break unless error_msg
      end

      label "しばらくお待ち下さい..."

      results = opt.messages.select { |message|
        message.class.slug == :worldon_status
      }.map { |message|
        message.reblog ? message.reblog : message
      }.sort_by { |message|
        message.account.acct
      }.chunk { |message|
        message.account.acct
      }.each { |acct, messages|
        world.report_for_spam(messages, result[:comment])
      }

      label "完了しました。"
    end
  end

  command(:worldon_pin_message, name: 'ピン留めする', visible: true, role: :timeline,
          condition: lambda { |opt|
            world, = Plugin.filtering(:world_current, nil)
            opt.messages.any? { |m| pin_message?(world, m) }
          }) do |opt|
    world, = Plugin.filtering(:world_current, nil)
    next unless world

    opt.messages.select{ |m|
      pin_message?(world, m)
    }.each { |status|
      world.pin(status)
    }
  end

  command(:worldon_unpin_message, name: 'ピン留めを解除する', visible: true, role: :timeline,
          condition: lambda { |opt|
            world, = Plugin.filtering(:world_current, nil)
            opt.messages.any? { |m| unpin_message?(world, m) }
          }) do |opt|
    world, = Plugin.filtering(:world_current, nil)
    next unless world

    opt.messages.select{ |m|
      unpin_message?(world, m)
    }.each { |status|
      world.unpin(status)
    }
  end

  command(:worldon_edit_list_membership, name: 'リストへの追加・削除', visible: true, role: :timeline,
          condition: lambda { |opt|
            world, = Plugin.filtering(:world_current, nil)
            [:worldon, :portal].include?(world.class.slug)
          }) do |opt|
    world, = Plugin.filtering(:world_current, nil)
    next unless world

    user = opt.messages.first&.user
    next unless user

    lists = world.get_lists!.inject(Hash.new) do |h, l|
      key = l[:id].to_sym
      val = l[:title]
      h[key] = val
      h
    end

    user_id = pm::API.get_local_account_id(world, user)
    result = pm::API.call(:get, world.domain, "/api/v1/accounts/#{user_id}/lists", world.access_token)
    membership = result.value.to_a.inject(Hash.new) do |h, l|
      key = l[:id].to_sym
      val = l[:title]
      h[key] = val
      h
    end


    dialog "リストへの追加・削除" do
      self[:lists] = membership.keys
      multiselect "所属させるリストを選択してください", :lists do
        lists.keys.each do |k|
          option(k, lists[k])
        end
      end
    end.next do |result|
      selected_ids = result[:lists]
      selected_ids.each do |list_id|
        unless membership[list_id]
          # 追加
          pm::API.call(:post, world.domain, "/api/v1/lists/#{list_id}/accounts", world.access_token, account_ids: [user_id])
        end
      end
      membership.keys.each do |list_id|
        unless selected_ids.include?(list_id)
          # 削除
          pm::API.call(:delete, world.domain, "/api/v1/lists/#{list_id}/accounts", world.access_token, account_ids: [user_id])
        end
      end
    end
  end

  command(:worldon_vote, name: '投票する', visible: true, role: :timeline,
          condition: lambda { |opt|
            m = opt.messages.first
            (m.is_a?(Plugin::Worldon::Status) &&
              m.poll &&
              [:worldon, :portal].include?(opt.world.class.slug))
          }) do |opt|
    m = opt.messages.first

    # poll idはサーバーごとに異なる。worldが所属するサーバーでの値を取得する。
    statuses = pm::API.status_by_url(opt.world.domain, opt.world.access_token, m.uri)
    next unless statuses
    next unless statuses[0]
    next unless statuses[0][:poll]
    poll = pm::Poll.new(statuses[0][:poll])
    next unless poll.expires_at >= Time.now

    dialog "投票" do
      if poll.multiple
        multiselect "投票先を選択してください", :vote do
          poll.options.each_index do |i|
            vopt = poll.options[i]
            option(i.to_s.to_sym, vopt.title)
          end
        end
      else
        select "投票先を選択してください", :vote do
          poll.options.each_index do |i|
            vopt = poll.options[i]
            option(i.to_s.to_sym, vopt.title) { } # ラジオボタン化のために空blockを渡す
          end
        end
      end
    end.next do |result|
      vote = result[:vote]
      unless [Array, Set].include? vote.class
        vote = [vote]
      end
      pm::API.call(:post, opt.world.domain, "/api/v1/polls/#{poll.id}/votes", opt.world.access_token, choices: vote)
    end.trap do |err|
      pm::Util.ppf(err)
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

    result = world.post(message: body, **opts)
    if result.nil?
      warn "投稿に失敗したかもしれません"
      $stdout.flush
      nil
    else
      new_status = pm::Status.build(world.domain, [result.value]).first
      Plugin.call(:posted, world, [new_status]) if new_status
      Plugin.call(:update, world, [new_status]) if new_status
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
      hash = pm::API.call(:post, world.domain, '/api/v1/media', world.access_token, file: tmp_path.to_s)
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

    result = world.post(to: status, message: body, **opts)
    if result.nil?
      warn "投稿に失敗したかもしれません"
      $stdout.flush
      nil
    else
      new_status = pm::Status.build(world.domain, [result.value]).first
      Plugin.call(:posted, world, [new_status]) if new_status
      Plugin.call(:update, world, [new_status]) if new_status
      new_status
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

  command(
    :worldon_update_profile,
    name: 'プロフィール変更',
    condition: -> (opt) {
      world = Plugin.filtering(:world_current, nil).first
      [:worldon, :portal].include?(world.class.slug)
    },
    visible: true,
    role: :postbox
  ) do |opt|
    world = Plugin.filtering(:world_current, nil).first

    profiles = Hash.new
    profiles[:name] = world.account.display_name
    profiles[:biography] = world.account.source.note
    profiles[:locked] = world.account.locked
    profiles[:bot] = world.account.bot
    profiles[:source] = {
      privacy: world.account.source.privacy,
      sensitive: world.account.source.sensitive,
      language: world.account.source.language,
      fields: world.account.source.fields.map{|f| { name: f.name, value: f.value } }
    }

    dialog "プロフィール変更" do
      self[:name] = profiles[:name]
      self[:biography] = profiles[:biography]
      self[:locked] = profiles[:locked]
      self[:bot] = profiles[:bot]
      self[:source_privacy] = visibility2select(profiles[:source][:privacy])
      self[:source_sensitive] = profiles[:source][:sensitive]
      (1..4).each do |i|
        next unless profiles[:source][:fields][i - 1]
        self[:"field_name#{i}"] = profiles[:source][:fields][i - 1][:name]
        self[:"field_value#{i}"] = profiles[:source][:fields][i - 1][:value]
      end

      input '表示名', :name
      multitext 'プロフィール', :biography
      photoselect 'アイコン', :icon
      photoselect 'ヘッダー', :header
      boolean '承認制アカウントにする', :locked
      boolean 'これは BOT アカウントです', :bot
      select "デフォルトの公開範囲", :source_privacy do
        option :"1public", "公開"
        option :"2unlisted", "未収載"
        option :"3private", "非公開"
        option :"4direct", "ダイレクト"
      end
      boolean 'メディアを常に閲覧注意としてマークする', :source_sensitive
      settings "プロフィール補足情報" do
        input 'ラベル1', :field_name1
        input '内容1', :field_value1
        input 'ラベル2', :field_name2
        input '内容2', :field_value2
        input 'ラベル3', :field_name3
        input '内容3', :field_value3
        input 'ラベル4', :field_name4
        input '内容4', :field_value4
      end
    end.next do |result|
      diff = Hash.new
      diff[:name] = result[:name] if (result[:name] && result[:name].size > 0 && profiles[:name] != result[:name])
      diff[:biography] = result[:biography] if (result[:biography] && result[:biography].size > 0 && profiles[:biography] != result[:biography])
      diff[:locked] = result[:locked] if profiles[:locked] != result[:locked]
      diff[:bot] = result[:bot] if profiles[:bot] != result[:bot]
      diff[:icon] = Pathname(result[:icon]) if result[:icon]
      diff[:header] = Pathname(result[:header]) if result[:header]
      diff[:source] = Hash.new
      diff[:source][:privacy] = select2visibility(result[:source_privacy]) if profiles[:source][:privacy] != select2visibility(result[:source_privacy])
      diff[:source][:sensitive] = result[:source_sensitive] if profiles[:source][:sensitive] != result[:source_sensitive]
      diff.delete(:source) if diff[:source].empty?
      if (1..4).any?{|i| result[:"field_name#{i}"] && result[:"field_value#{i}"] }
        (1..4).each do |i|
          name = result[:"field_name#{i}"]
          next unless name
          value = result[:"field_value#{i}"]
          next unless value
          diff[:"field_name#{i}"] = name
          diff[:"field_value#{i}"] = value
        end
      end
      next if diff.empty?

      world.update_profile(**diff)
    end
  end

  # 検索
  intent :worldon_tag, label: "Mastodonハッシュタグ(Worldon)" do |token|
    Plugin.call(:search_start, "##{token.model.name}")
  end

  # アカウント
  intent :worldon_account, label: "Mastodonアカウント(Worldon)" do |token|
    Plugin.call(:worldon_account_timeline, token.model)
  end

  on_worldon_account_timeline do |account|
    acct, domain = account.acct.split('@')
    tl_slug = :"worldon-account-timeline_#{acct}@#{domain}"
    tab :"worldon-account-tab_#{acct}@#{domain}" do |i_tab|
      set_icon account.icon
      set_deletable true
      temporary_tab
      timeline(tl_slug) do
        order do |message|
          ord = message.created.to_i
          if message.is_a? pm::AccountProfile
            ord = [5000000000000000, GLib::MAXLONG].min
          elsif message.respond_to?(:pinned?) && message.pinned?
            bias = 66200000000000
            ord = [ord + bias, GLib::MAXLONG - 1].min
          end
          ord
        end
      end
    end
    timeline(tl_slug).active!
    profile = pm::AccountProfile.new(account: account)
    timeline(tl_slug) << profile

    Thread.new do
      world, = Plugin.filtering(:world_current, nil)
      if [:worldon, :portal].include? world.class.slug
        account_id = pm::API.get_local_account_id(world, account)

        res = pm::API.call(:get, world.domain, "/api/v1/accounts/#{account_id}/statuses?pinned=true", world.access_token)
        if res.value
          timeline(tl_slug) << pm::Status.build(world.domain, res.value.map{|record|
            record[:pinned] = true
            record
          })
        end

        res = pm::API.call(:get, world.domain, "/api/v1/accounts/#{account_id}/statuses", world.access_token)
        if res.value
          timeline(tl_slug) << pm::Status.build(world.domain, res.value)
        end

        next if domain == world.domain
      end

      headers = {
        'Accept' => 'application/activity+json'
      }
      res = pm::API.call(:get, domain, "/users/#{acct}/outbox?page=true", nil, {}, headers)
      next unless res[:orderedItems]

      res[:orderedItems].map do |record|
        case record[:type]
        when "Create"
          # トゥート
          record[:object][:url]
        when "Announce"
          # ブースト
          pm::Status::TOOT_ACTIVITY_URI_RE.match(record[:atomUri]) do |m|
            "https://#{m[:domain]}/@#{m[:acct]}/#{m[:status_id]}"
          end
        end
      end.compact.each do |url|
        status = pm::Status.findbyurl(url) || pm::Status.fetch(url)
        timeline(tl_slug) << status if status
      end
    end
  end

  defspell(:search, :worldon) do |world, **opts|
    count = [opts[:count], 40].min
    q = opts[:q]
    if q.start_with? '#'
      q = URI.encode_www_form_component(q[1..-1])
      resp = Plugin::Worldon::API.call(:get, world.domain, "/api/v1/timelines/tag/#{q}", world.access_token, limit: count)
      return nil if resp.nil?
      resp = resp.to_a
    else
      resp = Plugin::Worldon::API.call(:get, world.domain, '/api/v2/search', world.access_token, q: q)
      return nil if resp.nil?
      resp = resp[:statuses]
    end
    Plugin::Worldon::Status.build(world.domain, resp)
  end

  defspell(:follow, :worldon, :worldon_account,
           condition: -> (world, account) { !world.following?(account.acct) }
          ) do |world, account|
    world.follow(account)
  end

  defspell(:unfollow, :worldon, :worldon_account,
           condition: -> (world, account) { world.following?(account.acct) }
          ) do |world, account|
    world.unfollow(account)
  end

  defspell(:following, :worldon, :worldon_account,
           condition: -> (world, account) { true }
          ) do |world, account|
    world.following?(account)
  end

  defspell(:mute_user, :worldon, :worldon_account,
           condition: -> (world, account) { !Plugin::Worldon::Status.muted?(account.acct) }
          ) do |world, account|
    world.mute(account)
  end

  defspell(:unmute_user, :worldon, :worldon_account,
           condition: -> (world, account) { Plugin::Worldon::Status.muted?(account.acct) }
          ) do |world, account|
    world.unmute(account)
  end

  defspell(:block_user, :worldon, :worldon_account,
           condition: -> (world, account) { !world.block?(account.acct) }
          ) do |world, account|
    world.block(account)
  end

  defspell(:unblock_user, :worldon, :worldon_account,
           condition: -> (world, account) { world.block?(account.acct) }
          ) do |world, account|
    world.unblock(account)
  end

  defspell(:report_for_spam, :worldon, :worldon_status) do |world, status, comment: raise|
    world.report_for_spam([status], comment)
  end

  defspell(:report_for_spam, :worldon) do |world, messages:, comment: raise|
    world.report_for_spam(messages, comment)
  end

  defspell(:pin_message, :worldon, :worldon_status,
           condition: -> (world, status) {
            world.account.acct == status.account.acct && !status.pinned?
            # 自分のStatusが（ピン留め状態が不正確になりうるタイミングで）他サーバーから取得されることはまずないと仮定している
           }
          ) do |world, status|
    world.pin(status)
  end

  defspell(:unpin_message, :worldon, :worldon_status,
           condition: -> (world, status) {
            world.account.acct == status.account.acct && status.pinned?
            # 自分のStatusが（ピン留め状態が不正確になりうるタイミングで）他サーバーから取得されることはまずないと仮定している
           }
          ) do |world, status|
    world.unpin(status)
  end

end
