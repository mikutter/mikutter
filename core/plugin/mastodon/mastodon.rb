# -*- coding: utf-8 -*-
require 'pp'

module Plugin::Mastodon
  PM = Plugin::Mastodon
  CLIENT_NAME = Environment::NAME
  WEB_SITE = 'https://mikutter.hachune.net/'
end

require_relative 'util'
require_relative 'api'
require_relative 'parser'
require_relative 'model/model'
require_relative 'patch'
require_relative 'spell'
require_relative 'setting'
require_relative 'subparts_status_info'
require_relative 'extractcondition'
require_relative 'rest'
require_relative 'score'

Plugin.create(:mastodon) do
  pm = Plugin::Mastodon

  defimageopener(_('Mastodon添付画像'), %r<\Ahttps?://[^/]+/system/media_attachments/files/[0-9]{3}/[0-9]{3}/[0-9]{3}/\w+/\w+\.\w+(?:\?\d+)?\Z>) do |url|
    open(url)
  end

  defimageopener(_('Mastodon添付画像（短縮）'), %r<\Ahttps?://[^/]+/media/[0-9A-Za-z_-]+(?:\?\d+)?\Z>) do |url|
    open(url)
  end

  defimageopener(_('Mastodon添付画像(proxy)'), %r<\Ahttps?://[^/]+/media_proxy/[0-9]+/(?:original|small)\z>) do |url|
    open(url)
  end

  defevent :mastodon_appear_toots, prototype: [[pm::Status]]

  defactivity :mastodon_followings_update, _('プロフィール・フォロー関係の取得通知(Mastodon)')

  filter_extract_datasources do |dss|
    datasources = { mastodon_appear_toots: _('受信したすべてのトゥート(Mastodon)') }
    [datasources.merge(dss)]
  end

  on_mastodon_appear_toots do |statuses|
    Plugin.call(:extract_receive_message, :mastodon_appear_toots, statuses)
  end

  followings_updater = Proc.new do
    activity(:mastodon_followings_update, _('自分のプロフィールやフォロー関係を取得しています...'))
    Plugin.filtering(:mastodon_worlds, nil).first.to_a.each do |world|
      Delayer::Deferred.when(
        world.update_account,
        world.blocks,
        world.followings(cache: false)
      ).next{
        activity(:mastodon_followings_update, _('自分のプロフィールやフォロー関係の取得が完了しました(%{acct})') % {acct: world.account.acct})
        Plugin.call(:world_modify, world)
      }.terminate(_('自分のプロフィールやフォロー関係が取得できませんでした(%{acct})') % {acct: world.account.acct})
    end

    Reserver.new(10 * HYDE, &followings_updater) # 26分ごとにプロフィールとフォロー一覧を更新する
  end

  # 起動時
  Delayer.new {
    followings_updater.call
  }


  # world系

  defevent :mastodon_worlds, prototype: [NilClass]

  # すべてのmastodon worldを返す
  filter_mastodon_worlds do
    [Enumerator.new{|y|
      Plugin.filtering(:worlds, y)
    }.select{|world|
      world.class.slug == :mastodon
    }.to_a]
  end

  defevent :mastodon_current, prototype: [NilClass]

  # world_currentがmastodonならそれを、そうでなければ適当に探す。
  filter_mastodon_current do
    world, = Plugin.filtering(:world_current, nil)
    unless mastodon?(world)
      worlds, = Plugin.filtering(:mastodon_worlds, nil)
      world = worlds.first
    end
    [world]
  end

  on_userconfig_modify do |key, value|
    if [:mastodon_enable_streaming, :extract_tabs].include?(key)
      Plugin.call(:mastodon_restart_all_streams)
    end
  end

  # サーバー編集
  on_mastodon_update_instance do |domain|
    Thread.new {
      instance = pm::Instance.load(domain)
      next if instance.nil? # 既存にない

      Plugin.call(:mastodon_restart_instance_stream, domain)
    }
  end

  # サーバー削除
  on_mastodon_delete_instance do |domain|
    Plugin.call(:mastodon_remove_instance_stream, domain)
    if UserConfig[:mastodon_instances].has_key?(domain)
      config = UserConfig[:mastodon_instances].dup
      config.delete(domain)
      UserConfig[:mastodon_instances] = config
    end
  end

  # world追加時用
  on_mastodon_create_or_update_instance do |domain|
    pm::Instance.add_ifn(domain).next do
      Plugin.call(:mastodon_restart_instance_stream, domain)
    end
  end

  on_world_create do |world|
    if world.class.slug == :mastodon
      slug_param = {id: Digest::SHA1.hexdigest(world.uri.to_s), domain: world.domain}
      name_param = {name: world.user_obj.acct, domain: world.domain}
      htl_slug = ('mastodon_htl_%{id}' % slug_param).to_sym
      mention_slug = ('mastodon_mentions_%{id}' % slug_param).to_sym
      ltl_slug = ('mastodon_ltl_%{domain}' % slug_param).to_sym
      exists_slugs = Set.new(Plugin.filtering(:extract_tabs_get, []).first.map(&:slug))
      if !exists_slugs.include?(htl_slug)
        Plugin.call(:extract_tab_create, {
                      name: _('ホームタイムライン (%{name})') % name_param,
                      slug: htl_slug,
                      sources: [world.datasource_slug(:home)],
                      icon: Skin[:timeline].uri,
                    })
      end
      if !exists_slugs.include?(mention_slug)
        Plugin.call(:extract_tab_create, {
                      name: _('メンション (%{name})') % name_param,
                      slug: mention_slug,
                      sources: [:mastodon_appear_toots],
                      sexp: [:or, [:include?, :receiver_idnames, world.user_obj.idname]],
                      icon: Skin[:reply].uri,
                    })
      end
      if !exists_slugs.include?(ltl_slug)
        Plugin.call(:extract_tab_create, {
                      name: _('ローカルタイムライン (%{domain})') % name_param,
                      slug: ltl_slug,
                      sources: [Plugin::Mastodon::Instance.datasource_slug(world.domain, :local)],
                      icon: 'https://%{domain}/apple-touch-icon.png' % slug_param,
                    })
      end
    end
  end

  # world追加
  on_world_create do |world|
    if world.class.slug == :mastodon
      Plugin.call(:mastodon_create_or_update_instance, world.domain, true)
    end
  end

  # world削除
  on_world_destroy do |world|
    if world.class.slug == :mastodon
      Delayer.new {
        worlds = Plugin.filtering(:mastodon_worlds, nil).first
        # 他のworldで使わなくなったものは削除してしまう。
        # filter_worldsから削除されるのはココと同様にon_world_destroyのタイミングらしいので、
        # この時点では削除済みである保証はなく、そのためworld.slugで判定する必要がある（はず）。
        unless worlds.any?{|w| w.slug != world.slug && w.domain != world.domain }
          Plugin.call(:mastodon_delete_instance, world.domain)
        end
        Plugin.call(:mastodon_remove_auth_stream, world)
      }
    end
  end

  defmodelviewer(Plugin::Mastodon::Account) do |user|
    [
      [_('名前'), user.display_name],
      [_('acct'), user.acct],
      *user.fields&.map{|f|
        f.emojis ||= user.emojis
        [f.name, f]
      },
      [_('フォロー'), user.following_count],
      [_('フォロワー'), user.followers_count],
      [_('Toot'), user.statuses_count]
    ]
  end

  deffragment(Plugin::Mastodon::Account, :bio, _("ユーザについて")) do |user|
    set_icon user.icon
    score = score_of(user.profile)
    bio = ::Gtk::IntelligentTextview.new(score)
    container = ::Gtk::VBox.new.
                  closeup(bio).
                  closeup(relation_bar(user))
    scrolledwindow = ::Gtk::ScrolledWindow.new
    scrolledwindow.set_policy(::Gtk::POLICY_AUTOMATIC, ::Gtk::POLICY_AUTOMATIC)
    scrolledwindow.add_with_viewport(container)
    scrolledwindow.style = container.style
    wrapper = Gtk::EventBox.new
    nativewidget wrapper.add(scrolledwindow)
  end

  # フォロー関係の表示・操作用ウィジェット
  def relation_bar(user)
    icon_size = Gdk::Rectangle.new(0, 0, 32, 32)
    arrow_size = Gdk::Rectangle.new(0, 0, 16, 16)
    container = ::Gtk::VBox.new(false, 4)

    Plugin.filtering(:mastodon_worlds, nil).first.each do |me|
      following = followed = blocked = false

      w_following_label = ::Gtk::Label.new(_("関係を取得中"))
      w_followed_label = ::Gtk::Label.new("")
      w_eventbox_image_following = ::Gtk::EventBox.new
      w_eventbox_image_followed = ::Gtk::EventBox.new

      w_following_relation = if me.account == user
                               ::Gtk::Label.new(_("それはあなたです！"))
                             else
                               ::Gtk::HBox.new.
                                 closeup(w_eventbox_image_following).
                                 closeup(w_following_label)
                             end

      w_followed_relation = ::Gtk::HBox.new.
                              closeup(w_eventbox_image_followed).
                              closeup(w_followed_label)

      relation_container = ::Gtk::HBox.new(false, icon_size.width/2)
      relation_container.closeup(::Gtk::WebIcon.new(me.account.icon, icon_size).tooltip(me.title))
      relation_container.closeup(::Gtk::VBox.new.
                                 closeup(w_following_relation).
                                 closeup(w_followed_relation))
      relation_container.closeup(::Gtk::WebIcon.new(user.icon, icon_size).tooltip(user.title))

      if me.account != user
        m_get_relationship = -> {
          Plugin::Mastodon::API.get_local_account_id(me, user).next { |aid|
            Plugin::Mastodon::API.call(:get, me.domain, '/api/v1/accounts/relationships', me.access_token, id: [aid]).next { |resp|
              resp[0]
            }.trap { |e|
              Deferred.fail(e)
            }
          }
        }

        followbutton = ::Gtk::Button.new
        menubutton = ::Gtk::Button.new(" … ")

        m_button_sensitive = -> (new) {
          followbutton.sensitive = new unless followbutton.destroyed?
          menubutton.sensitive = new unless menubutton.destroyed?
        }
        m_button_sensitive.call(false)

        m_following_refresh = -> {
          next if w_eventbox_image_following.destroyed?

          if not w_eventbox_image_following.children.empty?
            w_eventbox_image_following.remove(w_eventbox_image_following.children.first)
          end

          w_eventbox_image_following.style = w_eventbox_image_following.parent.style
          w_eventbox_image_following.add(::Gtk::WebIcon.new(Skin[following ? 'arrow_following.png' : 'arrow_notfollowing.png'], arrow_size).show_all)
          w_following_label.text = if blocked
                                     _("ﾌﾞﾖｯｸしている")
                                   elsif following
                                     _("ﾌｮﾛｰしている")
                                   else
                                     _("ﾌｮﾛｰしていない")
                                   end
          followbutton.label = (blocked || following) ? _("解除") : _("ﾌｮﾛｰ")
        }

        m_followed_refresh = -> {
          next if w_eventbox_image_followed.destroyed?

          if not w_eventbox_image_followed.children.empty?
            w_eventbox_image_followed.remove(w_eventbox_image_followed.children.first)
          end

          w_eventbox_image_followed.style = w_eventbox_image_followed.parent.style
          w_eventbox_image_followed.add(::Gtk::WebIcon.new(Skin.get_path(followed ? "arrow_followed.png" : "arrow_notfollowed.png"), arrow_size).show_all)
          w_followed_label.text = followed ? _("ﾌｮﾛｰされている") : _("ﾌｮﾛｰされていない")
        }

        followbutton.ssc(:clicked) do
          m_button_sensitive.call(false)
          verb = if blocked
                   :unblock_user
                 elsif following
                   :unfollow
                 else
                   :follow
                 end
          spell(verb, me, user).next {
            case verb
            when :unblock_user
              blocked = false
            when :unfollow
              following = false
            else
              following = true
            end

            m_following_refresh.call
            m_button_sensitive.call(true)
          }.terminate.trap {
            m_button_sensitive.call(true)
          }
        end

        menubutton.ssc(:clicked) do
          menu = ::Gtk::Menu.new
          menu.ssc(:selection_done) do
            menu.destroy
            false
          end
          menu.ssc(:cancel) do
            menu.destroy
            false
          end

          muted = Plugin::Mastodon::Status.muted?(user.acct)
          menu.append(::Gtk::MenuItem.new(muted ? _("ミュート解除する") : _("ミュートする")).tap { |item|
                        item.ssc(:activate) {
                          m_button_sensitive.call(false)
                          spell(muted ? :unmute_user : :mute_user, me, user).next {
                            m_following_refresh.call
                            m_button_sensitive.call(true)
                          }.terminate.trap {
                            m_button_sensitive.call(true)
                          }
                        }
                      })
          menu.append(::Gtk::MenuItem.new(blocked ? _("ブロック解除する") : _("ブロックする")).tap { |item|
                        item.ssc(:activate) {
                          m_button_sensitive.call(false)
                          spell(blocked ? :unblock_user : :block_user, me, user).next {
                            blocked = !blocked
                            following = false if blocked
                            m_following_refresh.call
                            m_button_sensitive.call(true)
                          }.terminate.trap {
                            m_button_sensitive.call(true)
                          }
                        }
                      })

          menu.show_all.popup(nil, nil, 0, 0)
        end

        m_get_relationship.call.next { |relationship|
          following = relationship[:following]
          followed = relationship[:followed_by]
          blocked = relationship[:blocking]

          m_following_refresh.call
          m_followed_refresh.call
          m_button_sensitive.call(true)

          unless relation_container.destroyed?
            relation_container.closeup(followbutton).closeup(menubutton)
            followbutton.show
            menubutton.show
          end
        }.terminate.trap {
          w_following_label.text = _("取得できませんでした")
        }
      end

      container.closeup(relation_container)
    end

    container
  end

  deffragment(Plugin::Mastodon::Account, :user_timeline, _('ユーザタイムライン')) do |user|
    set_icon Skin[:timeline]
    tl = timeline(nil) do
      order do |message|
        retweet = message.retweeted_statuses.find{ |r| user.id == r.user.id }
        (retweet || message).created.to_i
      end
    end
    world, = Plugin.filtering(:mastodon_current, nil)
    Plugin::Mastodon::API.get_local_account_id(world, user).next{ |account_id|
      Plugin::Mastodon::API.call(:get, world.domain, "/api/v1/accounts/#{account_id}/statuses", world.access_token).next{ |res|
        if res.value
          tl << pm::Status.build(world.domain, res.value)
        end
      }
    }.terminate
    if domain != world.domain
      acct, domain = user.acct.split('@', 2)
      Plugin::Mastodon::API.call(
        :get, domain, "/users/#{acct}/outbox?page=true",
        nil,
        {},
        {'Accept' => 'application/activity+json'}).next{ |res|
        next unless res[:orderedItems]
        res[:orderedItems].map{|record|
          case record[:type]
          when "Create"
            # トゥート
            record[:object][:url]
          when "Announce"
            # ブースト
            Plugin::Mastodon::Status::TOOT_ACTIVITY_URI_RE.match(record[:atomUri]) do |m|
              "https://#{m[:domain]}/@#{m[:acct]}/#{m[:status_id]}"
            end
          end
        }.compact.each do |url|
          status = Plugin::Mastodon::Status.findbyuri(url) || +Plugin::Mastodon::Status.fetch(url)
          tl << status if status
        end
      }.terminate
    end
  end

  # world作成
  world_setting(:mastodon, _('Mastodon')) do
    set_value domain_selection: 'social.mikutter.hachune.net'
    error_msg = nil
    while true
      if error_msg.is_a? String
        label error_msg
      end
      select(_('サーバー'), :domain_selection,
             'social.mikutter.hachune.net' => _('mikutter'),
             'mstdn.maud.io' => _('末代'),
             'mstdn.nere9.help' => _('nere9'),
             'mstdn.y-zu.org' => _('Yづドン'),
            ) do
        option(:other, _('その他')) do
          input _('ドメイン'), :domain
        end
      end

      result = await_input
      domain = result[:domain_selection] == :other ? result[:domain] : result[:domain_selection]

      instance = await pm::Instance.add_ifn(domain).trap{ nil }
      if instance.nil?
        error_msg = _("%{domain} サーバーへの接続に失敗しました。やり直してください。") % {domain: domain}
        next
      end

      break
    end

    error_msg = nil
    while true
      if error_msg.is_a? String
        label error_msg
      end
      label _('Webページにアクセスして表示された認証コードを入力して、次へボタンを押してください。')
      link instance.authorize_url
      input _('認証コード'), :authorization_code
      if error_msg.is_a? String
        input _('アクセストークンがあれば入力してください'), :access_token
      end
      result = await_input
      if result[:authorization_code]
        result[:authorization_code].strip!
      end
      if result[:access_token]
        result[:access_token].strip!
      end

      if ((result[:authorization_code].nil? || result[:authorization_code].empty?) && (result[:access_token].nil? || result[:access_token].empty?))
        error_msg = _('認証コードを入力してください')
        next
      end

      break
    end

    if result[:authorization_code]
      resp = pm::API.call!(:post, domain, '/oauth/token',
                           client_id: instance.client_key,
                           client_secret: instance.client_secret,
                           grant_type: 'authorization_code',
                           redirect_uri: 'urn:ietf:wg:oauth:2.0:oob',
                           code: result[:authorization_code]
                          )
      if resp.nil? || resp.value.has_key?(:error)
        label _('認証に失敗しました。') + (resp && resp[:error] ? "：#{resp[:error]}" : '')
        await_input
        raise (resp.nil? ? 'error has occurred at /oauth/token' : resp[:error])
      end
      token = resp[:access_token]
    else
      token = result[:access_token]
    end

    resp = pm::API.call!(:get, domain, '/api/v1/accounts/verify_credentials', token)
    if resp.nil? || resp.value.has_key?(:error)
      label _('アカウント情報の取得に失敗しました') + (resp && resp[:error] ? "：#{resp[:error]}" : '')
      raise (resp.nil? ? 'error has occurred at verify_credentials' : resp[:error])
    end

    screen_name = resp[:acct] + '@' + domain
    resp[:acct] = screen_name
    account = pm::Account.new(resp.value)
    world = pm::World.new(
      id: screen_name,
      slug: :"mastodon:#{screen_name}",
      domain: domain,
      access_token: token,
      account: account
    )
    world.update_mutes!

    label _('認証に成功しました。このアカウントを追加しますか？')
    label(_('アカウント名：%{screen_name}') % {screen_name: screen_name})
    label(_('ユーザー名：%{display_name}') % {display_name: resp[:display_name]})
    world
  end
end
