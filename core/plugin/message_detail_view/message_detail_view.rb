# -*- coding: utf-8 -*-
require_relative 'header_widget'

Plugin.create(:message_detail_view) do
  command(:message_detail_view_show,
          name: '詳細',
          condition: lambda{ |opt| opt.messages.size == 1 },
          visible: true,
          role: :timeline) do |opt|
    Plugin.call(:show_message, opt.messages.first)
  end

  on_show_message do |message|
    show_message(message)
  end

  def show_message(message, force=false)
    slug = "message_detail_view-#{message.id}".to_sym
    if !force and Plugin::GUI::Tab.exist?(slug)
      Plugin::GUI::Tab.instance(slug).active!
    else
      container = Plugin::MessageInspector::HeaderWidget.new(message)
      i_cluster = tab slug, _("詳細タブ") do
        set_icon Skin.get('message.png')
        set_deletable true
        temporary_tab
        shrink
        nativewidget container
        expand
        cluster nil end
      Thread.new {
        Plugin.filtering(:message_detail_view_fragments, [], i_cluster, message).first
      }.next { |tabs|
        tabs.map(&:last).each(&:call)
      }.next {
        if !force
          i_cluster.active! end }.terminate(_('詳細表示中にエラーが発生しました'))
    end
  end

  style = -> do
    Gtk::Style.new().tap do |bg_style|
      color = UserConfig[:mumble_basic_bg]
      bg_style.set_bg(Gtk::STATE_ACTIVE, *color)
      bg_style.set_bg(Gtk::STATE_NORMAL, *color)
      bg_style.set_bg(Gtk::STATE_SELECTED, *color)
      bg_style.set_bg(Gtk::STATE_PRELIGHT, *color)
      bg_style.set_bg(Gtk::STATE_INSENSITIVE, *color) end end

  message_fragment :body, "body" do
    set_icon Skin.get('message.png')
    container = Gtk::HBox.new
    textview = Gtk::IntelligentTextview.new(retriever.to_s, 'font' => :mumble_basic_font, style: style)
    vscrollbar = Gtk::VScrollbar.new
    textview.set_scroll_adjustment(nil, vscrollbar.adjustment)
    container.add textview
    container.closeup vscrollbar
    nativewidget container
  end
end

