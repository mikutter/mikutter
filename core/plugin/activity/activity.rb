# -*- coding: utf-8 -*-
# 通知管理プラグイン

miquire :mui, 'tree_view_pretty_scroll'

require "set"

# アクティビティの設定の並び順
UserConfig[:activity_kind_order] ||= ["retweet", "favorite", "follow", "list_member_added", "list_member_removed", "dm", "system", "error"]
# アクティビティタブに保持する通知の数
UserConfig[:activity_max] ||= 1000

Plugin.create(:activity) do

  class ActivityView < ::Gtk::CRUD
    include ::Gtk::TreeViewPrettyScroll

    ICON = 0
    KIND = 1
    TITLE = 2
    DATE = 3
    PLUGIN = 4
    ID = 5
    SERVICE = 6
    EVENT = 7

    def initialize(plugin)
      type_strict plugin => Plugin
      @plugin = plugin
      super()
      @creatable = @updatable = @deletable = false
    end

    def column_schemer
      [{:kind => :pixbuf, :type => Gdk::Pixbuf, :label => 'icon'}, # ICON
       {:kind => :text, :type => String, :label => _('種類')},      # KIND
       {:kind => :text, :type => String, :label => _('説明')},      # TITLE
       {:kind => :text, :type => String, :label => _('時刻')},      # DATE
       {:type => Plugin},                                          # PLUGIN
       {:type => Integer},                                         # IDu
       {:type => Service},                                         # SERVICE
       {:type => Hash} ].freeze                                    # EVENT
    end

    def method_missing(*args, &block)
      @plugin.__send__(*args, &block)
    end
  end

  BOOT_TIME = Time.new.freeze

  # そのイベントをミュートするかどうかを返す(trueなら表示しない)
  def mute?(params)
    mute_kind = UserConfig[:activity_mute_kind]
    if mute_kind.is_a? Array
      return true if mute_kind.include? params[:kind].to_s end
    mute_kind_related = UserConfig[:activity_mute_kind_related]
    if mute_kind_related
      return true if mute_kind_related.include?(params[:kind].to_s) and !params[:related] end
    false end

  # このIDの組み合わせが出現したことがないなら真
  # ==== Args
  # [event] イベント名
  # [ids] ID
  # ==== Return
  # 初めて表示するキーなら真
  def show_once(event, *ids)
    @show_once ||= Hash.new{ |h, k| h[k] = [] }
    result = []
    ids.each_with_index{ |id, index|
      storage = @show_once[event][index] ||= Set.new
      if storage.include? id
        result << true
      else
        storage << id
        result << false end }
    not result.all? end

  # アクティビティの古い通知を一定時間後に消す
  def reset_activity(model)
    Reserver.new(60) {
      Delayer.new {
        if not model.destroyed?
          iters = model.to_enum(:each).to_a
          remove_count = iters.size - UserConfig[:activity_max]
          if remove_count > 0
            iters[-remove_count, remove_count].each{ |mpi|
              model.remove(mpi[2]) } end
          reset_activity(model) end } }
  end

  def gen_listener_for_visible_check(uc, kind)
    UserConfig[uc] ||= []
    Plugin::Settings::Listener.new \
      get: ->(){ UserConfig[uc].include?(kind) rescue false },
      set: ->(value) do
        if value
          UserConfig[uc] += [kind]
        else
          UserConfig[uc] -= [kind] end end end

  def gen_listener_for_invisible_check(uc, kind)
    UserConfig[uc] ||= []
    Plugin::Settings::Listener.new \
      get: ->(){ (not UserConfig[uc].include?(kind)) rescue true },
      set: ->(value) do
        unless value
          UserConfig[uc] += [kind]
        else
          UserConfig[uc] -= [kind] end end end

  # 新しいアクティビティの種類を定義する。設定に表示されるようになる
  # ==== Args
  # [kind] 種類
  # [name] 表示する名前
  defdsl :defactivity do |kind, name|
    filter_activity_kind do |data|
      data[kind] = name
      [data] end end

  activity_view = ActivityView.new(self)
  activity_vscrollbar = ::Gtk::VScrollbar.new(activity_view.vadjustment)
  activity_hscrollbar = ::Gtk::HScrollbar.new(activity_view.hadjustment)
  activity_shell = ::Gtk::Table.new(2, 2)
  activity_description = ::Gtk::IntelligentTextview.new
  activity_status = ::Gtk::Label.new
  activity_container = ::Gtk::VPaned.new
  activity_detail_view = Gtk::ScrolledWindow.new

  reset_activity(activity_view.model)

  activity_detail_view.
    set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_AUTOMATIC).
    set_height_request(88)

  activity_container.
    pack1(activity_shell.
               attach(activity_view, 0, 1, 0, 1, ::Gtk::FILL|::Gtk::SHRINK|::Gtk::EXPAND, ::Gtk::FILL|::Gtk::SHRINK|::Gtk::EXPAND).
               attach(activity_vscrollbar, 1, 2, 0, 1, ::Gtk::FILL, ::Gtk::SHRINK|::Gtk::FILL).
               attach(activity_hscrollbar, 0, 1, 1, 2, ::Gtk::SHRINK|::Gtk::FILL, ::Gtk::FILL),
          true, true).
    pack2(activity_detail_view.add_with_viewport(::Gtk::VBox.new.
                                  closeup(activity_description).
                                  closeup(activity_status.right)), true, false)

  tab(:activity, _("アクティビティ")) do
    set_icon Skin.get("activity.png")
    nativewidget ::Gtk::EventBox.new.add(activity_container)
  end

  activity_view.ssc("cursor-changed") { |this|
    iter = this.selection.selected
    if iter
      activity_description.rewind(iter[ActivityView::EVENT][:description])
      activity_status.set_text(iter[ActivityView::DATE])
    end
    false
  }

  # アクティビティ更新を受け取った時の処理
  # plugin, kind, title, icon, date, service
  on_modify_activity do |params|
    if not mute?(params)
      activity_view.scroll_to_zero_lator! if activity_view.realized? and activity_view.vadjustment.value == 0.0
      iter = activity_view.model.prepend
      if params[:icon].is_a? String
        iter[ActivityView::ICON] = Gdk::WebImageLoader.pixbuf(params[:icon], 24, 24){ |loaded_icon|
          iter[ActivityView::ICON] = loaded_icon }
      else
        iter[ActivityView::ICON] = params[:icon] end
      iter[ActivityView::KIND] = params[:kind].to_s
      iter[ActivityView::TITLE] = params[:title].tr("\n", "")
      iter[ActivityView::DATE] = params[:date].strftime('%Y/%m/%d %H:%M:%S')
      iter[ActivityView::PLUGIN] = params[:plugin]
      iter[ActivityView::ID] = 0
      iter[ActivityView::SERVICE] = params[:service]
      iter[ActivityView::EVENT] = params
      if (UserConfig[:activity_show_timeline] || []).include?(params[:kind].to_s)
        Plugin.call(:update, nil, [Message.new(message: params[:description], system: true, source: params[:plugin].to_s, created: params[:date])])
      end
      if (UserConfig[:activity_show_statusbar] || []).include?(params[:kind].to_s)
        Plugin.call(:gui_window_rewindstatus, Plugin::GUI::Window.instance(:default), "#{params[:kind]}: #{params[:title]}", 10)
      end
    end
  end

  on_favorite do |service, user, message|
    activity(:favorite, "#{message.user[:idname]}: #{message.to_s}",
             description:(_("@%{user} がふぁぼふぁぼしました") % {user: user[:idname]} + "\n" +
                          "@#{message.user[:idname]}: #{message.to_s}\n"+
                          message.parma_link),
             icon: user[:profile_image_url],
             related: message.user.me? || user.me?,
             service: service)
  end

  on_unfavorite do |service, user, message|
    activity(:unfavorite, "#{message.user[:idname]}: #{message.to_s}",
             description:(_("@%{user} があんふぁぼしました") % {user: user[:idname]} + "\n" +
                          "@#{message.user[:idname]}: #{message.to_s}\n"+
                          message.parma_link),
             icon: user[:profile_image_url],
             related: message.user.me? || user.me?,
             service: service)
  end

  on_retweet do |retweets|
    retweets.each { |retweet|
      retweet.retweet_source_d.next{ |source|
        activity(:retweet, retweet.to_s,
                 description:(_("@%{user} がリツイートしました") % {user: retweet.user[:idname]} + "\n" +
                              "@#{source.user[:idname]}: #{source.to_s}\n"+
                              source.parma_link),
                 icon: retweet.user[:profile_image_url],
                 date: retweet[:created],
                 related: (retweet.user.me? || source && source.user.me?),
                 service: Service.primary) }.terminate(_ 'リツイートソースが取得できませんでした') }
  end

  on_list_member_added do |service, user, list, source_user|
    if show_once(:list_member_added, user[:id], list[:id])
      title = _("@%{user}が%{list}に追加されました") % {
        user: user[:idname],
        list: list[:full_name] }
      desc_by_user = {
        description: list[:description],
        user: list.user[:idname] }
      activity(:list_member_added, title,
               description:("#{title}\n" +
                            _("%{description} (by @%{user})") % desc_by_user + "\n" +
                            "https://twitter.com/#{list.user[:idname]}/#{list[:slug]}"),
               icon: user[:profile_image_url],
               related: user.me? || source_user.me?,
               service: service) end
  end

  on_list_member_removed do |service, user, list, source_user|
    if show_once(:list_member_removed, user[:id], list[:id])
      title = _("@%{user}が%{list}から削除されました") % {
        user: user[:idname],
        list: list[:full_name] }
      desc_by_user = {
        description: list[:description],
        user: list.user[:idname] }
      activity(:list_member_removed, title,
               description:("#{title}\n"+
                            _("%{description} (by @%{user})") % desc_by_user + "\n" +
                            "https://twitter.com/#{list.user[:idname]}/#{list[:slug]}"),
               icon: user[:profile_image_url],
               related: user.me? || source_user.me?,
               service: service) end
  end

  on_follow do |by, to|
    if show_once(:follow, by[:id], to[:id])
      by_user_to_user = {
        followee: by[:idname],
        follower: to[:idname] }
      activity(:follow, _("@%{followee} が @%{follower} をﾌｮﾛｰしました") % by_user_to_user,
               related: by.me? || to.me?,
               icon: (to.me? ? by : to)[:profile_image_url]) end
  end

  on_direct_messages do |service, dms|
    dms.each{ |dm|
      date = Time.parse(dm[:created_at])
      if date > BOOT_TIME
        first_line = dm[:sender].me? ? _("ダイレクトメッセージを送信しました") : _("ダイレクトメッセージを受信しました")
        title = _("D %{recipient} %{text}") % {
          recipient: dm[:recipient][:idname],
          text: dm[:text] }
        activity(:dm, title,
                 description: ("#{first_line}\n" +
                               "@#{dm[:sender][:idname]}: #{title}"),
                 icon: dm[:sender][:profile_image_url],
                 service: service,
                 date: date) end }
  end

  onunload do
    Addon.remove_tab _('アクティビティ')
  end

  settings _("アクティビティ") do
    activity_kind = Plugin.filtering(:activity_kind, {})
    activity_kind_order = TypedArray(String).new
    if activity_kind
      activity_kind = activity_kind.last
      activity_kind.keys.each{ |kind|
        kind = kind.to_s
        i = where_should_insert_it(kind, activity_kind_order, UserConfig[:activity_kind_order])
        activity_kind_order.insert(i, kind) }
    else
      activity_kind_order = []
      activity_kind = {} end

    activity_kind_order.each do |kind|
      name = activity_kind[kind]
      ml_param = {name: name}
      settings name do
        boolean(_('%{name}を表示する') % ml_param, gen_listener_for_invisible_check(:activity_mute_kind, kind)).tooltip(_('%{name}を、アクティビティタイムラインに表示します。チェックを外すと、%{name}の他の設定は無効になります。') % ml_param)
        boolean(_('自分に関係ない%{name}も表示する') % ml_param, gen_listener_for_invisible_check(:activity_mute_kind_related, kind)).tooltip(_('自分に関係ない%{name}もアクティビティタイムラインに表示されるようになります。チェックを外すと、自分に関係ない%{name}は表示されません。') % ml_param)
        boolean(_('タイムラインに表示'), gen_listener_for_visible_check(:activity_show_timeline, kind)).tooltip(_('%{name}が通知された時に、システムメッセージで%{name}を通知します') % ml_param)
        boolean(_('ステータスバーに表示'), gen_listener_for_visible_check(:activity_show_statusbar, kind)).tooltip(_('%{name}が通知された時に、ステータスバーにしばらく表示します') % ml_param)
      end
    end
  end

  defactivity "retweet", _("リツイート")
  defactivity "favorite", _("ふぁぼ")
  defactivity "follow", _("フォロー")
  defactivity "list_member_added", _("リストに追加")
  defactivity "list_member_removed", _("リストから削除")
  defactivity "dm", _("ダイレクトメッセージ")
  defactivity "system", _("システムメッセージ")
  defactivity "error", _("エラー")

end
