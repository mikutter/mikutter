# -*- coding: utf-8 -*-

Plugin.create :display_requirements do

  on_gui_timeline_join_tab do |i_timeline, i_tab|
    i_tab.shrink
    i_tab.nativewidget(Gtk::WebIcon.new(MUI::Skin.get("twitter-bird.png"), 32, 32))
    i_tab.expand
  end

end

class ::Gdk::MiraclePainter
  def header_left_markup
    Pango.parse_markup("<b>#{Pango.escape(message[:user][:name] || '')}</b> @#{Pango.escape(message[:user][:idname])}")
  end

  def timestamp_label
    now = Time.now.to_i
    there = message[:created].to_i
    diff = (there - now).abs
    case diff
    when 0
      "今"
    when 1...60
      "#{diff}秒#{there < now ? '前' : "後"}"
    when 60...3600
      "#{(diff/60).to_i}分#{there < now ? '前' : "後"}"
    when 3600...86400
      "#{(diff/3600).to_i}時間#{there < now ? '前' : "後"}"
    else
      message[:created].strftime('%Y/%m/%d')
    end
  end

end
