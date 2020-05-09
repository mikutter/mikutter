# -*- coding: utf-8 -*-
# frozen_string_literal: true

Plugin.create(:mastodon_account_viewer) do
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
    wrapper.no_show_all = true
    wrapper.show
    nativewidget wrapper.add(scrolledwindow)
    wrapper.ssc(:expose_event) do
      wrapper.no_show_all = false
      wrapper.show_all
      false
    end
  end

  # フォロー関係の表示・操作用ウィジェット
  def relation_bar(user)
    icon_size = Gdk::Rectangle.new(0, 0, 32, 32)
    arrow_size = Gdk::Rectangle.new(0, 0, 16, 16)
    container = ::Gtk::VBox.new(false, 4)

    Plugin.collect(:mastodon_worlds).each do |me|
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
                          if muted
                            m_button_sensitive.call(false)
                            unmute_user(me, user).next {
                              m_following_refresh.call
                              m_button_sensitive.call(true)
                            }.terminate.trap {
                              m_button_sensitive.call(true)
                            }
                          else
                            dialog(_('ミュートする')) {
                              label _('以下のユーザーをミュートしますか？')
                              link user
                            }.next {
                              m_button_sensitive.call(false)
                              mute_user(me, user).next {
                                m_following_refresh.call
                                m_button_sensitive.call(true)
                              }.terminate.trap {
                                m_button_sensitive.call(true)
                              }
                            }
                          end
                        }
                      })
          menu.append(::Gtk::MenuItem.new(blocked ? _("ブロック解除する") : _("ブロックする")).tap { |item|
                        item.ssc(:activate) {
                          if blocked
                            m_button_sensitive.call(false)
                            unblock_user(me, user).next {
                              blocked = false
                              m_following_refresh.call
                              m_button_sensitive.call(true)
                            }.terminate.trap {
                              m_button_sensitive.call(true)
                            }
                          else
                            dialog(_('ブロックする')) {
                              label _('以下のユーザーをブロックしますか？')
                              link user
                            }.next {
                              m_button_sensitive.call(false)
                              block_user(me, user).next {
                                blocked = true
                                following = false
                                m_following_refresh.call
                                m_button_sensitive.call(true)
                              }.terminate.trap {
                                m_button_sensitive.call(true)
                              }
                            }
                          end
                        }
                      })

          menu.show_all.popup(nil, nil, 0, 0)
        end

        Plugin::Mastodon::API.get_local_account_id(me, user).next { |aid|
          Plugin::Mastodon::API.call(:get, me.domain, '/api/v1/accounts/relationships', me.access_token, id: [aid]).next { |resp|
            resp[0]
          }.trap { |e|
            Deferred.fail(e)
          }
        }.next { |relationship|
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
        tl << Plugin::Mastodon::Status.bulk_build(world.server, res.value)
      }
    }.terminate
    acct, domain = user.acct.split('@', 2)
    if domain != world.domain
      Plugin::Mastodon::API.call(
        :get, domain, "/users/#{acct}/outbox?page=true",
        nil,
        {},
        {'Accept' => 'application/activity+json'}).next{ |res|
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
end
