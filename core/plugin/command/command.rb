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
    notice "new_pane: move tab :#{tab.slug}"
    window = tab.ancestor_of(Plugin::GUI::Window)
    if window
      pane = Plugin::GUI::Pane.instance
      pane << tab
      window << pane
    else
      error "window not found."
    end
  end

  command(:close,
          name: 'タブを閉じる',
          condition: lambda{ |opt|
            notice "tab close: #{opt.widget} deletable = #{opt.widget.deletable.inspect}"
            opt.widget.deletable },
          visible: true,
          role: :tab) do |opt|
    opt.widget.destroy
  end

  command(:focus_right_tab,
          name: '右のタブを選択',
          condition: lambda{ |opt| true },
          visible: false,
          role: :tab) do |opt|
    focus_move_widget(opt.widget, 1)
  end

  command(:focus_left_tab,
          name: '左のタブを選択',
          condition: lambda{ |opt| true },
          visible: false,
          role: :tab) do |opt|
    focus_move_widget(opt.widget, -1)
  end

  command(:focus_right_pane,
          name: '右のペインを選択',
          condition: lambda{ |opt| true },
          visible: false,
          role: :pane) do |opt|
    focus_move_widget(opt.widget, -1)
  end

  command(:focus_left_pane,
          name: '左のペインを選択',
          condition: lambda{ |opt| true },
          visible: false,
          role: :pane) do |opt|
    focus_move_widget(opt.widget, 1)
  end

  command(:focus_to_postbox,
          name: '投稿ボックスにフォーカス',
          condition: lambda{ |opt| not opt.widget.is_a? Plugin::GUI::Postbox },
          visible: false,
          role: :window) do |opt|
    focus_move_to_nearest_postbox(opt.widget.active_chain.last)
  end


  # フォーカスを _widget_ から _distance_ に移動する
  # ==== Args
  # [widget] 起点となるウィジェット
  # [distance] 移動距離
  def focus_move_widget(widget, distance)
    type_strict widget => Plugin::GUI::HierarchyParent
    type_strict widget => Plugin::GUI::HierarchyChild
    children = widget.parent.children.select{ |w| w.is_a? widget.class }
    index = children.index(widget)
    if distance > 0 ? (children.size <= (index+distance)) : (0 > (index+distance))
      notice "terminate #{widget}"
      yield(widget, distance) if block_given?
    else
      term = children[index + distance]
      term = term.active_chain.last if term.respond_to? :active_chain
      term.active! if term
      notice "activate #{term}"
    end
  end

  # 一番近い postbox にフォーカスを与える
  # ==== Args
  # [widget] 基準となるウィジェット
  def focus_move_to_nearest_postbox(widget)
    notice "called: given widget #{widget.inspect}"
    if widget.is_a? Plugin::GUI::HierarchyParent
      postbox = widget.children.find{ |w| w.is_a? Plugin::GUI::Postbox }
      notice "found postbox: #{postbox.inspect}"
      if postbox
        return postbox.active! end end
    if widget.is_a? Plugin::GUI::HierarchyChild
      focus_move_to_nearest_postbox(widget.parent) end end

end
