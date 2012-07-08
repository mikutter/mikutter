# -*- coding: utf-8 -*-

Plugin.create :command do

  command(:copy_selected_region,
          name: 'コピー',
          condition: lambda{ |opt| opt.messages.size == 1 && opt.widget.selected_text(opt.messages.first) },
          visible: true,
          role: :timeline) do |opt|
    Gtk::Clipboard.copy(opt.widget.selected_text(opt.messages.first)) end

  command(:copy_description,
          name: '本文をコピー',
          condition: lambda{ |opt| opt.messages.size == 1 },
          visible: true,
          role: :timeline) do |opt|
    Gtk::Clipboard.copy(opt.messages.first.to_show) end

  command(:reply,
          name: '返信',
          condition: lambda{ |opt| opt.messages.all? &:repliable? },
          visible: true,
          role: :timeline) do |opt|
    opt.widget.create_reply_postbox(opt.messages.first.message,
                                    subreplies: opt.messages.map(&:message)) end

  command(:reply_all,
          name: '全員に返信',
          condition: lambda{ |opt| opt.messages.all? &:repliable? },
          visible: true,
          role: :timeline) do |opt|
    opt.widget.create_reply_postbox(opt.messages.first.message,
                                    subreplies: opt.messages.map{ |m| m.message.ancestors }.flatten,
                                    exclude_myself: true) end

  command(:legacy_retweet,
          name: '引用',
          condition: lambda{ |opt| opt.messages.size == 1 && opt.messages.first.repliable? },
          visible: true,
          role: :timeline) do |opt|
    opt.widget.create_reply_postbox(opt.messages.first.message, retweet: true) end

  command(:retweet,
          name: 'リツイート',
          condition: lambda{ |opt|
            opt.messages.all? { |m|
              m.retweetable? and not m.retweeted_by_me? } },
          visible: true,
          role: :timeline) do |opt|
    opt.messages.select{ |x| not x.from_me? }.each(&:retweet) end

  command(:delete_retweet,
          name: 'リツイートをキャンセル',
          condition: lambda{ |opt|
            opt.messages.all? { |m|
              m.retweetable? and m.retweeted_by_me? } },
          visible: true,
          role: :timeline) do |opt|
    opt.messages.each { |m|
      retweet = m.retweeted_statuses.find(&:from_me?)
      retweet.destroy if retweet and Gtk::Dialog.confirm("このつぶやきのリツイートをキャンセルしますか？\n\n#{m.to_show}") } end

  command(:favorite,
          name: 'ふぁぼふぁぼする',
          condition: lambda{ |opt|
            opt.messages.all?{ |m| m.favoritable? and not m.favorited_by_me? } },
          visible: true,
          role: :timeline) do |opt|
    opt.messages.each(&:favorite) end

  command(:delete_favorite,
          name: 'あんふぁぼ',
          condition: lambda{ |opt|
            opt.messages.all?(&:favorited_by_me?) },
          visible: true,
          role: :timeline) do |opt|
    opt.messages.each(&:unfavorite) end

  command(:delete,
          name: '削除',
          condition: lambda{ |opt|
            opt.messages.all?(&:from_me?) },
          visible: true,
          role: :timeline) do |opt|
    opt.messages.each { |m|
      m.destroy if Gtk::Dialog.confirm("失った信頼はもう戻ってきませんが、本当にこのつぶやきを削除しますか？\n\n#{m.to_show}") } end

  command(:select_prev,
          name: '一つ上のメッセージを選択',
          condition: ret_nth,
          visible: false,
          role: :timeline) do |opt|
    Plugin.call(:gui_timeline_move_cursor_to, opt.widget, :prev) end

  command(:select_next,
          name: '一つ下のメッセージを選択',
          condition: ret_nth,
          visible: false,
          role: :timeline) do |opt|
    Plugin.call(:gui_timeline_move_cursor_to, opt.widget, :next) end

  command(:post_it,
          name: '投稿する',
          condition: lambda{ |opt| opt.widget.editable? },
          visible: false,
          role: :postbox) do |opt|
    opt.widget.post_it! end

  command(:google_search,
          name: 'ggrks',
          condition: lambda{ |opt| opt.messages.size == 1 && opt.widget.selected_text(opt.messages.first) },
          visible: true,
          role: :timeline) do |opt|
    Gtk::openurl("http://www.google.co.jp/search?q=" + URI.escape(opt.widget.selected_text(opt.messages.first)).to_s) end

  command(:open_link,
          name: 'リンクを開く',
          condition: lambda{ |opt|
            opt.messages.size == 1 && opt.messages[0].entity.to_a.any? {|u|
              u[:slug] == :urls } },
          visible: true,
          role: :timeline) do |opt|
    opt.messages[0].entity.to_a.each {|u|
      Gtk::TimeLine.openurl(u[:url]) if u[:slug] == :urls } end

  command(:new_pane,
          name: '新規ペインに移動',
          condition: lambda{ |opt|
            pane = opt.widget.parent
            notice "pane: #{pane}"
            pane.is_a?(Plugin::GUI::Pane) and pane.children.size != 1 },
          visible: true,
          role: :tab) do |opt|
    tab = opt.widget.is_a?(Plugin::GUI::Tab) ? opt.widget : opt.widget.ancestor_of(Plugin::GUI::Tab)
    window = tab.ancestor_of(Plugin::GUI::Window)
    if window
      pane = Plugin::GUI::Pane.instance
      pane << tab
      window << pane
    else
      error "window not found."
    end
  end
end
