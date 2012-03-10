# -*- coding: utf-8 -*-
# 通知管理プラグイン

miquire :mui, 'tree_view_pretty_scroll'
module Plugin::Activity
  # アクティビティを更新する。
  # ==== Args
  # [kind] Symbol イベントの種類
  # [description] 本文
  # [icon] String|Gdk::Pixbuf アイコン
  # [date] Time イベントの発生した時刻
  # [service] Service 関係するServiceオブジェクト
  # ==== Return
  # 
  def activity(kind, description, icon = nil, date = Time.now, service = nil)
    Plugin.call(:modify_activity, self, kind, description, icon, date, service)
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

  activity_view = ActivityView.new
  activity_scrollbar = Gtk::VScrollbar.new(activity_view.vadjustment)
  activity_shell = Gtk::HBox.new.pack_start(activity_view, activity_view).closeup(activity_scrollbar)
  Delayer.new do
    Plugin.call(:mui_tab_regist, activity_shell, 'アクティビティ', MUI::Skin.get("underconstruction.png"))
  end

  on_modify_activity do |plugin, kind, description, icon, date, service|
    iter = activity_view.model.prepend
    if icon.is_a? String
      iter[ActivityView::ICON] = Gdk::WebImageLoader.pixbuf(icon, 24, 24){ |loaded_icon|
        iter[ActivityView::ICON] = loaded_icon }
    else
      iter[ActivityView::ICON] = icon end
    iter[ActivityView::KIND] = kind.to_s
    iter[ActivityView::DESCRIPTION] = description.tr("\n", "")
    iter[ActivityView::DATE] = date.to_s
    iter[ActivityView::PLUGIN] = plugin
    iter[ActivityView::ID] = 0
    iter[ActivityView::SERVICE] = service
  end

  on_favorite do |service, user, message|
    activity :favorite, "#{message.user[:idname]}: #{message.to_s}", user[:profile_image_url], Time.new, service
  end

  on_unfavorite do |service, user, message|
    activity :unfavorite, "#{message.user[:idname]}: #{message.to_s}", user[:profile_image_url], Time.new, service
  end

  on_retweet do |retweets|
    retweets.each { |retweet|
      activity :retweet, retweet.to_s, retweet.user[:profile_image_url], retweet[:created], Service.primary }
  end

  on_list_member_added do |service, user, list, source_user|
    activity :list_member_added, "@#{user[:idname]}が#{list[:full_name]}に追加されました", user[:profile_image_url], Time.new, service
  end

  on_list_member_removed do |service, user, list, source_user|
    activity :list_member_removed, "@#{user[:idname]}が#{list[:full_name]}から削除されました", user[:profile_image_url], Time.new, service
  end

  on_follow do |by, to|
    activity :follow, "@#{by[:idname]}が@#{to[:idname]}をﾌｮﾛｰしました", (to.is_me? ? by : to)[:profile_image_url]
  end

end

