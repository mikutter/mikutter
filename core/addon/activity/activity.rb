# -*- coding: utf-8 -*-

module Plugin::Activity
  # アクティビティを更新する。
  # _icon_ は省略することができる
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
  Delayer.new do
    Plugin.call(:mui_tab_regist, activity_view, 'アクティビティ', MUI::Skin.get("underconstruction.png"))
  end

  on_modify_activity do |plugin, kind, description, icon, date, service|
    iter = activity_view.model.prepend
    if icon.is_a? String
      iter[ActivityView::ICON] = Gdk::WebImageLoader.pixbuf(icon, 16, 16){ |loaded_icon|
        iter[ActivityView::ICON] = loaded_icon }
    else
      iter[ActivityView::ICON] = icon end
    iter[ActivityView::KIND] = kind.to_s
    iter[ActivityView::DESCRIPTION] = description
    iter[ActivityView::DATE] = date.to_s
    iter[ActivityView::PLUGIN] = plugin
    iter[ActivityView::ID] = 0
    iter[ActivityView::SERVICE] = service
  end

  on_favorite do |service, user, message|
    activity :favorite, "#{user[:idname]}★#{message.user[:idname]}: #{message.to_s}", user[:profile_image_url], Time.new, service
  end

  on_retweet do |retweets|
    retweets.each { |retweet|
      activity :retweet, "#{retweet.user[:idname]}#{retweet.to_s}", retweet.user[:profile_image_url], retweet[:created], Service.primary }
  end

  on_rewindstatus do |mes|
    activity :status, mes
  end

end

