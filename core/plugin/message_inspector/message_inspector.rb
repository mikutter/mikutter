# -*- coding: utf-8 -*-
require_relative 'header_widget'

Plugin.create(:message_inspector) do
  command(:message_inspector_show,
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
    slug = "message-inspector-#{message.id}".to_sym
    if !force and Plugin::GUI::Tab.exist?(slug)
      Plugin::GUI::Tab.instance(slug).active!
    else
      container = Plugin::MessageInspector::HeaderWidget.new(message)
      i_message_inspector = tab slug, _("詳細タブ") do
        set_icon message.user[:profile_image_url]
        set_deletable true
        shrink
        nativewidget container
        expand
        cluster nil end
      Thread.new {
        Plugin.filtering(:message_inspector_tab, [], i_message_inspector, message).first
      }.next { |tabs|
        tabs.map(&:last).each(&:call)
      }.next {
        if !force
          i_message_inspector.active! end }
    end
  end
end
