# coding: utf-8

Plugin.create(:mastodon) do

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
    :mastodon_custom_post,
    name: _('カスタム投稿'),
    condition: ->(opt) do
      mastodon?(opt.world) && opt.widget.editable?
    end,
    visible: true,
    icon: Skin[:post],
    role: :postbox
  ) do |opt|
    i_postbox = opt.widget
    postbox, = Plugin.filtering(:gui_get_gtk_widget, i_postbox)
    body = postbox.widget_post.buffer.text
    reply_to = postbox.mastodon_get_reply_to

    dialog _('カスタム投稿') do
      # オプションを並べる
      multitext _('CW警告文'), :spoiler_text
      self[:body] = body
      multitext _('本文'), :body
      self[:sensitive] = opt.world.account.source.sensitive
      boolean _('閲覧注意'), :sensitive

      visibility_default = opt.world.account.source.privacy
      if reply_to.is_a?(Plugin::Mastodon::Status) && reply_to.visibility == "direct"
        # 返信先がDMの場合はデフォルトでDMにする。但し編集はできるようにするため、この時点でデフォルト値を代入するのみ。
        visibility_default = "direct"
      end
      self[:visibility] = visibility2select(visibility_default)
      select _('公開範囲'), :visibility do
        option :"1public", _('公開')
        option :"2unlisted", _('未収載')
        option :"3private", _('非公開')
        option :"4direct", _('ダイレクト')
      end

      settings _('添付メディア') do
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

      settings _('投票を受付ける') do
        input "1", :poll_options1
        input "2", :poll_options2
        input "3", :poll_options3
        input "4", :poll_options4
        select _('投票受付期間'), :poll_expires_in do
          option :min5, _('5分')
          option :hour, _('1時間')
          option :day, _('1日')
          option :week, _('1週間')
          option :month, _('1ヶ月')
        end
        boolean _('複数選択可にする'), :poll_multiple
        boolean _('終了するまで結果を表示しない'), :poll_hide_totals
      end
    end.next do |result|
      # 投稿
      # まず画像をアップロード
      media_ids = []
      media_urls = []
      (1..4).each do |i|
        if result[:"media#{i}"]
          path = Pathname(result[:"media#{i}"])
          hash = +Plugin::Mastodon::API.call(:post, opt.world.domain, '/api/v1/media', opt.world.access_token, file: path) # TODO: Deferred.whenを使えば複数枚同時アップロードできる
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

      compose(opt.world, reply_to, **opts)

      if Gtk::PostBox.list[0] != postbox
        postbox.destroy
      else
        postbox.widget_post.buffer.text = ''
      end
    end
  end

  command(:mastodon_report_status, name: _('通報する'), visible: true, role: :timeline,
          condition: lambda { |opt|
            opt.messages.any? { |m| report_for_spam?(opt.world, m) }
          }) do |opt|
    dialog _('通報する') do
      error_msg = nil
      while true
        label _('以下のトゥートを %{domain} サーバーの管理者に通報しますか？') % {domain: opt.world.domain}
        opt.messages.each { |message|
          link message
        }
        multitext _('コメント（1000文字以内） ※必須'), :comment
        label error_msg if error_msg

        result = await_input
        error_msg = _('コメントを入力してください。') if (!result[:comment] || result[:comment].empty?)
        error_msg = _('コメントが長すぎます（%{input_char_count}文字）') % {input_char_count: result[:comment].to_s.size} if result[:comment].to_s.size > 1000
        break unless error_msg
      end

      label _('しばらくお待ち下さい...')

      opt.messages.select { |message|
        message.class.slug == :mastodon_status
      }.map { |message|
        message.reblog ? message.reblog : message
      }.sort_by { |message|
        message.account.acct
      }.chunk { |message|
        message.account.acct
      }.each { |acct, messages|
        await opt.world.report_for_spam(messages, result[:comment])
      }

      label _('完了しました。')
    end.terminate(_('通報中にエラーが発生しました'))
  end

  command(:mastodon_pin_message, name: _('ピン留めする'), visible: true, role: :timeline,
          condition: lambda { |opt|
            opt.messages.any? { |m| pin_message?(opt.world, m) }
          }) do |opt|
    opt.messages.select{ |m|
      pin_message?(opt.world, m)
    }.each { |status|
      opt.world.pin(status)
    }
  end

  command(:mastodon_unpin_message, name: _('ピン留めを解除する'), visible: true, role: :timeline,
          condition: lambda { |opt|
            opt.messages.any? { |m| unpin_message?(opt.world, m) }
          }) do |opt|
    opt.messages.select{ |m|
      unpin_message?(opt.world, m)
    }.each { |status|
      opt.world.unpin(status)
    }
  end

  command(:mastodon_edit_list_membership, name: _('リストへの追加・削除'), visible: true, role: :timeline,
          condition: lambda { |opt|
            mastodon?(opt.world)
          }) do |opt|
    user = opt.messages.first&.user
    next unless user

    Delayer::Deferred.when(
      opt.world.get_lists,
      Plugin::Mastodon::API.get_local_account_id(opt.world, user)
    ).next{ |lists, user_id|
      old_membership_ids = Set.new(
        (+Plugin::Mastodon::API.call(:get, opt.world.domain, "/api/v1/accounts/#{user_id}/lists", opt.world.access_token))
          .value.map { |member| member[:id].to_sym }
      ).freeze

      dialog _('リストへの追加・削除') do
        self[:lists] = old_membership_ids
        multiselect _('所属させるリストを選択してください'), :lists do
          lists.each do |list|
            option(list[:id].to_sym, list[:title])
          end
        end
      end.next do |result|
        new_membership_ids = Set.new(result[:lists])
        Delayer::Deferred.when(
          *(new_membership_ids - old_membership_ids).map do |list_id|
            Plugin::Mastodon::API.call(:post, opt.world.domain, "/api/v1/lists/#{list_id}/accounts", opt.world.access_token, account_ids: [user_id])
          end,
          *(old_membership_ids - new_membership_ids).map do |list_id|
            Plugin::Mastodon::API.call(:delete, opt.world.domain, "/api/v1/lists/#{list_id}/accounts", opt.world.access_token, account_ids: [user_id])
          end
        ).next { |*_succeed|
          activity(:mastodon_background_succeeded, _('リストへの追加・削除が完了しました'))
        }.trap do |failed|
          activity(:mastodon_background_failed, _('リストへの追加・削除が失敗しました'), exception: failed)
        end
      end
    }.terminate
  end

  command(:mastodon_vote, name: _('投票する'), visible: true, role: :timeline,
          condition: ->(opt) {
            m = opt.messages.first
            (m.is_a?(Plugin::Mastodon::Status) && m.poll && mastodon?(opt.world))
          }) do |opt|
    m = opt.messages.first

    # poll idはサーバーごとに異なる。worldが所属するサーバーでの値を取得する。
    Plugin::Mastodon::API.status_by_url(opt.world.domain, opt.world.access_token, m.uri).next{ |statuses|
      Plugin::Mastodon::Poll.new(statuses.dig(0, :poll))
    }.next{ |poll|
      Delayer::Deferred.fail("The poll already expired.") unless poll.expires_at >= Time.now

      dialog _("投票") do
        if poll.multiple
          multiselect _("投票先を選択してください"), :vote do
            poll.options.each_with_index do |vopt, i|
              option(i.to_s.to_sym, vopt.title)
            end
          end
        else
          select _("投票先を選択してください"), :vote do
            poll.options.each_with_index do |vopt, i|
              option(i.to_s.to_sym, vopt.title) { } # ラジオボタン化のために空blockを渡す
            end
          end
        end
      end.next { |result|
        Plugin::Mastodon::API.call(:post, opt.world.domain, "/api/v1/polls/#{poll.id}/votes", opt.world.access_token, choices: Array(result[:vote]))
      }
    }.terminate
  end


  # spell系

  # 投稿
  defspell(:compose, :mastodon) do |world, body:, **opts|
    if opts[:visibility]
      opts[:visibility] = opts[:visibility].to_s
    else
      opts.delete :visibility
    end

    unless opts[:sensitive] || opts[:media_ids] || opts[:spoiler_text]
      opts[:sensitive] = false
    end

    world.post(message: body, **opts).next{ |result|
      new_status = Plugin::Mastodon::Status.build(world.server, result.value)
      Plugin.call(:posted, world, [new_status])
      Plugin.call(:update, world, [new_status])
      new_status
    }
  end

  memoize def media_tmp_dir
    path = Pathname(Environment::TMPDIR) / 'mastodon' / 'media'
    FileUtils.mkdir_p(path.to_s)
    path
  end

  defspell(:compose, :mastodon, :photo) do |world, photo, body:, **opts|
    photo.download.next{|photo|
      ext = photo.uri.path.split('.').last || 'png'
      tmp_name = Digest::MD5.hexdigest(photo.uri.to_s) + ".#{ext}"
      tmp_path = media_tmp_dir / tmp_name
      file_put_contents(tmp_path, photo.blob)
      Plugin::Mastodon::API.call(:post, world.domain, '/api/v1/media', world.access_token, file: tmp_path.to_s).next{ |hash|
        media_id = hash[:id]
        compose(world, body: body, media_ids: [media_id], **opts)
      }
    }
  end

  defspell(:compose, :mastodon, :mastodon_status) do |world, status, body:, **opts|
    if opts[:visibility]
      opts[:visibility] = opts[:visibility].to_s
    else
      opts.delete :visibility
      if status.visibility == "direct"
        # 返信先がDMの場合はデフォルトでDMにする。但し呼び出し元が明示的に指定してきた場合はそちらを尊重する。
        opts[:visibility] = "direct"
      end
    end
    unless opts[:sensitive] || opts[:media_ids] || opts[:spoiler_text]
      opts[:sensitive] = false
    end

    world.post(to: status, message: body, **opts).next{ |result|
      new_status = Plugin::Mastodon::Status.build(world.server, result.value)
      Plugin.call(:posted, world, [new_status]) if new_status
      Plugin.call(:update, world, [new_status]) if new_status
      new_status
    }
  end

  defspell(:destroy, :mastodon, :mastodon_status, condition: -> (world, status) {
             world.account.acct == status.actual_status.account.acct
           }) do |world, status|
    Plugin::Mastodon::API.get_local_status_id(world, status.actual_status).next{ |status_id|
      Plugin::Mastodon::API.call(:delete, world.domain, "/api/v1/statuses/#{status_id}", world.access_token)
    }.next{
      Plugin.call(:destroyed, [status.actual_status])
      status.actual_status
    }
  end

  # ふぁぼ
  defspell(:favorite, :mastodon, :mastodon_status,
           condition: -> (world, status) { !status.actual_status.favorite?(world) }
          ) do |world, status|
    Plugin::Mastodon::API.get_local_status_id(world, status.actual_status).next{ |status_id|
      Plugin.call(:before_favorite, world, world.account, status)
      Plugin::Mastodon::API.call(:post, world.domain, '/api/v1/statuses/' + status_id.to_s + '/favourite', world.access_token)
    }.next{ |ret|
      status.actual_status.favourited = true
      status.actual_status.favorite_accts << world.account.acct
      Plugin.call(:favorite, world, world.account, status)
    }.trap {
      Plugin.call(:fail_favorite, world, world.account, status)
    }
  end

  defspell(:favorited, :mastodon, :mastodon_status,
           condition: -> (world, status) { status.actual_status.favorite?(world) }
          ) do |world, status|
    Delayer::Deferred.new.next {
      status.actual_status.favorite?(world)
    }
  end

  defspell(:unfavorite, :mastodon, :mastodon_status, condition: -> (world, status) { status.favorite?(world) }) do |world, status|
    Plugin::Mastodon::API.get_local_status_id(world, status.actual_status).next{ |status_id|
      Plugin::Mastodon::API.call(:post, world.domain, '/api/v1/statuses/' + status_id.to_s + '/unfavourite', world.access_token)
    }.next{ |ret|
      status.actual_status.favourited = false
      status.actual_status.favorite_accts.delete(world.account.acct)
      Plugin.call(:favorite, world, world.account, status)
      status.actual_status
    }.terminate
  end

  # ブースト
  defspell(:share, :mastodon, :mastodon_status,
           condition: -> (world, status) { status.actual_status.rebloggable?(world) }
          ) do |world, status|
    world.reblog(status.actual_status).next{|shared|
      Plugin.call(:posted, world, [shared])
      Plugin.call(:update, world, [shared])
    }
  end

  defspell(:shared, :mastodon, :mastodon_status,
           condition: -> (world, status) { status.actual_status.shared?(world) }
          ) do |world, status|
    Delayer::Deferred.new.next {
      status.actual_status.shared?(world)
    }
  end

  defspell(:destroy_share, :mastodon, :mastodon_status, condition: -> (world, status) { status.actual_status.shared?(world) }) do |world, status|
    Plugin::Mastodon::API.get_local_status_id(world, status.actual_status).next{ |status_id|
      Plugin::Mastodon::API.call(:post, world.domain, '/api/v1/statuses/' + status_id.to_s + '/unreblog', world.access_token)
    }.next{ |ret|
      status.actual_status.reblogged = false
      reblog = status.actual_status.retweeted_statuses.find{|s|
        s.account.acct == world.user_obj.acct
      }
      status.actual_status.reblog_status_uris.delete_if {|pair| pair[:acct] == world.user_obj.acct }
      Plugin.call(:destroyed, [reblog]) if reblog
      reblog
    }
  end

  # プロフィール更新系
  update_profile_block = ->(world, **opts) do
    world.update_profile(**opts)
  end

  defspell(:update_profile, :mastodon, &update_profile_block)
  defspell(:update_profile_name, :mastodon, &update_profile_block)
  defspell(:update_profile_biography, :mastodon, &update_profile_block)
  defspell(:update_profile_icon, :mastodon, :photo) do |world, photo|
    update_profile_block.call(world, icon: photo)
  end
  defspell(:update_profile_header, :mastodon, :photo) do |world, photo|
    update_profile_block.call(world, header: photo)
  end

  command(
    :mastodon_update_profile,
    name: _('プロフィール変更'),
    condition: -> (opt) {
      mastodon?(opt.world)
    },
    visible: true,
    role: :postbox
  ) do |opt|
    profiles = Hash.new
    profiles[:name] = opt.world.account.display_name
    profiles[:biography] = opt.world.account.source.note
    profiles[:locked] = opt.world.account.locked
    profiles[:bot] = opt.world.account.bot
    profiles[:source] = {
      privacy: opt.world.account.source.privacy,
      sensitive: opt.world.account.source.sensitive,
      language: opt.world.account.source.language,
      fields: opt.world.account.source.fields.map{|f| { name: f.name, value: f.value } }
    }

    dialog _('プロフィール変更') do
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

      input _('表示名'), :name
      multitext _('プロフィール'), :biography
      photoselect _('アイコン'), :icon
      photoselect _('ヘッダー'), :header
      boolean _('承認制アカウントにする'), :locked
      boolean _('これは BOT アカウントです'), :bot
      select _('デフォルトの公開範囲'), :source_privacy do
        option :"1public", _('公開')
        option :"2unlisted", _('未収載')
        option :"3private", _('非公開')
        option :"4direct", _('ダイレクト')
      end
      boolean _('メディアを常に閲覧注意としてマークする'), :source_sensitive
      settings _('プロフィール補足情報') do
        input _('ラベル1'), :field_name1
        input _('内容1'), :field_value1
        input _('ラベル2'), :field_name2
        input _('内容2'), :field_value2
        input _('ラベル3'), :field_name3
        input _('内容3'), :field_value3
        input _('ラベル4'), :field_name4
        input _('内容4'), :field_value4
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

      opt.world.update_profile(**diff)
    end
  end

  # 検索
  intent :mastodon_tag, label: _('Mastodonハッシュタグ(Mastodon)') do |token|
    Plugin.call(:search_start, "##{token.model.name}")
  end

  defspell(:search, :mastodon) do |world, **opts|
    count = [opts[:count], 40].min
    q = opts[:q]
    if q.start_with? '#'
      q = URI.encode_www_form_component(q[1..-1])
      Plugin::Mastodon::API.call(:get, world.domain, "/api/v1/timelines/tag/#{q}", world.access_token, limit: count).next(&:to_a)
    else
      Plugin::Mastodon::API.call(:get, world.domain, '/api/v2/search', world.access_token, q: q).next{ |resp|
        resp[:statuses]
      }
    end.next{|resp|
      Plugin::Mastodon::Status.bulk_build(world.server, resp)
    }
  end

  defspell(:around_message, :mastodon_status) do |status|
    Thread.new do
      status.around(true)
    end
  end

  defspell(:follow, :mastodon, :mastodon_account,
           condition: -> (world, account) { !world.following?(account.acct) }
          ) do |world, account|
    world.follow(account)
  end

  defspell(:unfollow, :mastodon, :mastodon_account,
           condition: -> (world, account) { world.following?(account.acct) }
          ) do |world, account|
    world.unfollow(account)
  end

  defspell(:following, :mastodon, :mastodon_account
          ) do |world, account|
    world.following?(account)
  end

  defspell(:mute_user, :mastodon, :mastodon_account,
           condition: -> (world, account) { !Plugin::Mastodon::Status.muted?(account.acct) }
          ) do |world, account|
    world.mute(account)
  end

  defspell(:unmute_user, :mastodon, :mastodon_account,
           condition: -> (world, account) { Plugin::Mastodon::Status.muted?(account.acct) }
          ) do |world, account|
    world.unmute(account)
  end

  defspell(:block_user, :mastodon, :mastodon_account,
           condition: -> (world, account) { !world.block?(account.acct) }
          ) do |world, account|
    world.block(account)
  end

  defspell(:unblock_user, :mastodon, :mastodon_account,
           condition: -> (world, account) { world.block?(account.acct) }
          ) do |world, account|
    world.unblock(account)
  end

  defspell(:report_for_spam, :mastodon, :mastodon_status) do |world, status, comment: raise|
    world.report_for_spam([status], comment)
  end

  defspell(:report_for_spam, :mastodon) do |world, messages:, comment: raise|
    world.report_for_spam(messages, comment)
  end

  defspell(:pin_message, :mastodon, :mastodon_status,
           condition: -> (world, status) {
            world.account.acct == status.account.acct && !status.pinned?
            # 自分のStatusが（ピン留め状態が不正確になりうるタイミングで）他サーバーから取得されることはまずないと仮定している
           }
          ) do |world, status|
    world.pin(status)
  end

  defspell(:unpin_message, :mastodon, :mastodon_status,
           condition: -> (world, status) {
            world.account.acct == status.account.acct && status.pinned?
            # 自分のStatusが（ピン留め状態が不正確になりうるタイミングで）他サーバーから取得されることはまずないと仮定している
           }
          ) do |world, status|
    world.unpin(status)
  end

  defspell(:mastodon, :mastodon) do |mastodon|
    true
  end
end
