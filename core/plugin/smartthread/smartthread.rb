# -*- coding: utf-8 -*-

require 'set'

Plugin.create :smartthread do

  counter = gen_counter 1
  @timelines = {}                # slug => [message]

  # messagesの中で、タイムライン _slug_ に入れるべきものがあれば入れる
  # ==== Args
  # [slug] タイムラインスラッグ
  # [messages] 入れるMessageの配列
  def scan(slug, messages)
    seeds = @timelines[slug]
    i_timeline = timeline(slug)
    if i_timeline and seeds
      SerialThread.new do
        messages.each{ |message|
          message.each_ancestor { |cur|
            if seeds.include? cur
              i_timeline << message end } } end end end

  command(:smartthread,
          name: _('会話スレッドを表示'),
          icon: Skin.get("list.png"),
          condition: lambda{ |opt| not opt.messages.empty? and opt.messages.all? &:repliable? },
          visible: true,
          role: :timeline){ |opt|
    Plugin.call(:open_smartthread, opt.messages)
  }

  on_open_smartthread do |messages|
    serial = counter.call
    slug = "conversation#{serial}".to_sym
    tab slug, _("会話%{serial_id}") % {serial_id: serial} do
      set_deletable true
      set_icon Skin.get("list.png")
      temporary_tab
      timeline slug do
        order do |message|
          message[:created].to_i end end end
    @timelines[slug] = messages.map(&:ancestor).uniq
    timeline(slug) << messages.map(&:around).flatten
    tl = timeline(slug)
    @timelines[slug].each{ |message|
      Thread.new{
        message.each_ancestor(true){ |child|
          tl << child } }.trap{|e| error e} }
    timeline(slug).active! end

  onappear do |messages|
    @timelines.keys.each{ |slug|
      scan slug, messages } end

  # 引用ツイートをsmartthreadに含める処理。
  # 会話に新しいMessageが登録される時点で、そのMessageの引用ツイートを取得して格納していく
  on_gui_timeline_add_messages do |widget, messages|
    if widget.is_a?(Plugin::GUI::Timeline) and @timelines.include?(widget.slug)
      messages.deach do |message|
        message.quoting_messages_d(true).next{|quoting_messages|
          widget << widget.not_in_message(quoting_messages) unless quoting_messages.empty?
        }.terminate(_('引用ツイートが取得できませんでした'))
        widget << widget.not_in_message(message.quoted_by) if message.quoted_by?
      end
    end
  end

  on_gui_destroy do |widget|
    if widget.is_a? Plugin::GUI::Timeline
      @timelines.delete(widget.slug) end end

end
