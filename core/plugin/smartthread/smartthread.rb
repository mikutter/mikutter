# -*- coding: utf-8 -*-

require 'set'

Plugin.create :smartthread do

  counter = gen_counter 1
  @timeline_slugs = Set.new               # [Symbol]

  # messagesの中で、タイムライン _slug_ に入れるべきものがあれば入れる
  # ==== Args
  # [timeline] タイムライン
  # [messages] 入れるMessageの配列
  def scan(i_timeline, messages)
    SerialThread.new do
      messages.each{ |message|
        message.each_ancestor { |cur|
          if i_timeline.include? cur
            i_timeline << message
          end
        }
      }
    end
  end

  command(:smartthread,
          name: _('会話スレッドを表示'),
          icon: Skin[:list],
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
      set_icon Skin[:list]
      temporary_tab
      timeline slug do
        order do |message|
          message[:created].to_i end end end
    @timeline_slugs << slug
    i_timeline = timeline(slug)
    i_timeline << messages
    Delayer::Deferred.when(*messages.map{|m| around_message(m) }).next{ |around_all|
      i_timeline << around_all.flatten
    }
    timeline(slug).active!
  end

  onappear do |messages|
    @timeline_slugs.map{|s| timeline(s) }.each do |i_timeline|
      scan i_timeline, messages
    end
  end

  # 引用ツイートをsmartthreadに含める処理。
  # 会話に新しいMessageが登録される時点で、そのMessageの引用ツイートを取得して格納していく
  on_gui_timeline_add_messages do |widget, messages|
    if @timeline_slugs.include?(widget.slug)
      messages.deach do |message|
        message.quoting_messages_d(true).next{|quoting_messages|
          widget << widget.not_in_message(quoting_messages) unless quoting_messages.empty?
        }.terminate(_('引用ツイートが取得できませんでした'))
        widget << widget.not_in_message(message.quoted_by) if message.quoted_by?
      end
    end
  end

  on_gui_timeline_add_messages do |widget, messages|
    if widget.is_a?(Plugin::GUI::Timeline) && !@timeline_slugs.include?(widget.slug)
      Delayer::Deferred.new {
        graph = Hash.new{|h,k| h[k] = Set.new }
        messages.select(&:has_receive_message?).each{|m| graph[+m.replyto_source_d(true)] << m }
        if !graph.empty?
          @timeline_slugs.map{|s| timeline(s) }.each do |tl|
            tl.in_message(graph.keys).each do |parent|
              tl << graph[parent]
            end
          end
        end
      }.terminate('なんかへんなことになった')
    end
  end

  on_gui_destroy do |widget|
    if widget.is_a? Plugin::GUI::Timeline
      @timeline_slugs.delete(widget.slug)
    end
  end

end
