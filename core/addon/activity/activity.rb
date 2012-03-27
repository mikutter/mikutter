# -*- coding: utf-8 -*-
# 通知管理プラグイン

miquire :mui, 'tree_view_pretty_scroll'
module Plugin::Activity
  # アクティビティを更新する。
  # ==== Args
  # [kind] Symbol イベントの種類
  # [description] 本文
  # [args] その他オプション。主に以下の値
  #   icon :: String|Gdk::Pixbuf アイコン
  #   date :: Time イベントの発生した時刻
  #   service :: Service 関係するServiceオブジェクト
  #   related :: 自分に関係するかどうかのフラグ
  def activity(kind, description, args = {})
    Plugin.call(:modify_activity,
                { plugin: self,
                  kind: kind,
                  description: description }.merge(args))
  end
end

class Plugin
  include Plugin::Activity
end

Plugin.create :activity do
  class ActivityView < Gtk::CRUD
    include Gtk::TreeViewPrettyScroll

    ICON = 0
    KIND = 1
    DESCRIPTION = 2
    DATE = 3
    PLUGIN = 4
    ID = 5
    SERVICE = 6

    def initialize
      super()
      @creatable = @updatable = @deletable = false
    end

    def column_schemer
      [{:kind => :pixbuf, :type => Gdk::Pixbuf, :label => 'icon'}, # ICON
       {:kind => :text, :type => String, :label => '種類'},        # KIND
       {:kind => :text, :type => String, :label => '説明'},        # DESCRIPTION
       {:kind => :text, :type => String, :label => '時刻'},        # DATE
       {:type => Plugin},                                          # PLUGIN
       {:type => Integer},                                         # ID
       {:type => Service} ].freeze                                 # SERVICE
    end
  end

  # そのイベントをミュートするかどうかを返す(trueなら表示しない)
  def mute?(params)
    mute_kind = UserConfig[:activity_mute_kind]
    if mute_kind.is_a? Array
      return true if mute_kind.include? params[:kind].to_s end
    mute_kind_related = UserConfig[:activity_mute_kind_related]
    if mute_kind_related
      return true if mute_kind_related.include?(params[:kind].to_s) and !params[:related] end
    false end

  activity_view = ActivityView.new
  activity_scrollbar = Gtk::VScrollbar.new(activity_view.vadjustment)
  activity_shell = Gtk::HBox.new.pack_start(activity_view, activity_view).closeup(activity_scrollbar)
  Delayer.new do
    Plugin.call(:mui_tab_regist, activity_shell, 'アクティビティ', MUI::Skin.get("underconstruction.png"))
  end

  # アクティビティ更新を受け取った時の処理
  # plugin, kind, description, icon, date, service
  on_modify_activity do |params|
    if not mute?(params)
      iter = activity_view.model.prepend
      if params[:icon].is_a? String
        iter[ActivityView::ICON] = Gdk::WebImageLoader.pixbuf(params[:icon], 24, 24){ |loaded_icon|
          iter[ActivityView::ICON] = loaded_icon }
      else
        iter[ActivityView::ICON] = params[:icon] end
      iter[ActivityView::KIND] = params[:kind].to_s
      iter[ActivityView::DESCRIPTION] = params[:description].tr("\n", "")
      iter[ActivityView::DATE] = params[:date].to_s
      iter[ActivityView::PLUGIN] = params[:plugin]
      iter[ActivityView::ID] = 0
      iter[ActivityView::SERVICE] = params[:service]
    end
  end

  on_favorite do |service, user, message|
    activity(:favorite, "#{message.user[:idname]}: #{message.to_s}",
             icon: user[:profile_image_url],
             related: message.user.is_me? || user.is_me?,
             service: service)
  end

  on_unfavorite do |service, user, message|
    activity(:unfavorite, "#{message.user[:idname]}: #{message.to_s}",
             icon: user[:profile_image_url],
             related: message.user.is_me? || user.is_me?,
             service: service)
  end

  on_retweet do |retweets|
    retweets.each { |retweet|
      related = lazy{
        if retweet.user.is_me?
          true
        else
          retweet_source = retweet.retweet_source(false)
          retweet_source && retweet_source.user.is_me? end }
      activity(:retweet, retweet.to_s,
               icon: retweet.user[:profile_image_url],
               date: retweet[:created],
               related: related,
               service: Service.primary) }
  end

  on_list_member_added do |service, user, list, source_user|
    activity(:list_member_added, "@#{user[:idname]}が#{list[:full_name]}に追加されました",
             icon: user[:profile_image_url],
             related: user.is_me? || source_user.is_me?,
             service: service)
  end

  on_list_member_removed do |service, user, list, source_user|
    activity(:list_member_removed, "@#{user[:idname]}が#{list[:full_name]}から削除されました",
             icon: user[:profile_image_url],
             related: user.is_me? || source_user.is_me?,
             service: service)
  end

  on_follow do |by, to|
    activity(:follow, "@#{by[:idname]}が@#{to[:idname]}をﾌｮﾛｰしました",
             related: by.is_me? || to.is_me?,
             icon: (to.is_me? ? by : to)[:profile_image_url])
  end

end

Plugin.create :activity do
  settings "アクティビティ" do
    settings "表示しないイベントの「種類」" do
      multiselect("自分に関係ない種類を除外", :activity_mute_kind_related) do
        option "retweet", "リツイート"
        option "favorite", "ふぁぼ"
        option "follow", "フォロー"
        option "list_member_added", "リストに追加"
        option "list_member_removed", "リストから削除"
      end

      multiselect("以下の種類を除外", :activity_mute_kind) do
        option "retweet", "リツイート"
        option "favorite", "ふぁぼ"
        option "follow", "フォロー"
        option "list_member_added", "リストに追加"
        option "list_member_removed", "リストから削除"
      end

    end
  end
end
