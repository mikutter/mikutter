# -*- coding: utf-8 -*-

require File.expand_path File.join(File.dirname(__FILE__), 'conditions')

Plugin.create :command do

  on_gui_child_activated do |i_window, i_pane|
    if i_window.is_a?(Plugin::GUI::Window) and i_pane.is_a?(Plugin::GUI::Pane)
      last_active_pane[i_window.slug] = i_pane end end

  command(:copy_selected_region,
          name: 'コピー',
          condition: Plugin::Command[:HasOneMessage, :TimelineTextSelected],
          visible: true,
          icon: Skin.get("copy.png"),
          role: :timeline) do |opt|
    ::Gtk::Clipboard.copy(opt.widget.selected_text(opt.messages.first)) end

  command(:copy_description,
          name: '本文をコピー',
          condition: Plugin::Command[:HasOneMessage],
          visible: true,
          icon: Skin.get("copy_all.png"),
          role: :timeline) do |opt|
    ::Gtk::Clipboard.copy(opt.messages.first.to_show) end

  command(:reply,
          name: '返信',
          condition: Plugin::Command[:CanReplyAll],
          visible: true,
          icon: Skin.get("reply.png"),
          role: :timeline) do |opt|
    opt.widget.create_reply_postbox(opt.messages.first.message,
                                    subreplies: opt.messages.map(&:message)) end

  command(:reply_all,
          name: '全員に返信',
          condition: Plugin::Command[:CanReplyAll],
          visible: true,
          icon: Skin.get("reply.png"),
          role: :timeline) do |opt|
    opt.widget.create_reply_postbox(opt.messages.first.message,
                                    subreplies: opt.messages.map{ |m| m.message.ancestors }.flatten,
                                    exclude_myself: true) end

  command(:legacy_retweet,
          name: '引用',
          condition: Plugin::Command[:HasOneMessage, :CanReplyAll],
          visible: true,
          role: :timeline) do |opt|
    opt.widget.create_reply_postbox(opt.messages.first.message, retweet: true) end

  command(:retweet,
          name: 'リツイート',
          condition: Plugin::Command[:CanReTweetAll],
          visible: true,
          icon: Skin.get("retweet.png"),
          role: :timeline) do |opt|
    opt.messages.select{ |x| not x.from_me? }.each(&:retweet) end

  command(:delete_retweet,
          name: 'リツイートをキャンセル',
          condition: Plugin::Command[:IsReTweetedAll],
          visible: true,
          icon: Skin.get("retweet_cancel.png"),
          role: :timeline) do |opt|
    opt.messages.each { |m|
      retweet = m.retweeted_statuses.find(&:from_me?)
      retweet.destroy if retweet and ::Gtk::Dialog.confirm("このつぶやきのリツイートをキャンセルしますか？\n\n#{m.to_show}") } end

  command(:favorite,
          name: 'ふぁぼふぁぼする',
          condition: Plugin::Command[:CanFavoriteAll],
          visible: true,
          icon: Skin.get("unfav.png"),
          role: :timeline) do |opt|
    opt.messages.each(&:favorite) end

  command(:delete_favorite,
          name: 'あんふぁぼ',
          condition: Plugin::Command[:IsFavoritedAll],
          visible: true,
          icon: Skin.get("fav.png"),
          role: :timeline) do |opt|
    opt.messages.each(&:unfavorite) end

  command(:delete,
          name: '削除',
          condition: Plugin::Command[:IsMyMessageAll],
          visible: true,
          icon: Skin.get("close.png"),
          role: :timeline) do |opt|
    opt.messages.each { |m|
      m.destroy if ::Gtk::Dialog.confirm("失った信頼はもう戻ってきませんが、本当にこのつぶやきを削除しますか？\n\n#{m.to_show}") } end

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
          condition: Plugin::Command[:Editable],
          visible: false,
          icon: Skin.get("post.png"),
          role: :postbox) do |opt|
    opt.widget.post_it! end

  command(:google_search,
          name: 'ggrks',
          condition: Plugin::Command[:HasOneMessage, :TimelineTextSelected],
          visible: true,
          icon: "https://www.google.co.jp/images/google_favicon_128.png",
          role: :timeline) do |opt|
    ::Gtk::openurl("http://www.google.co.jp/search?q=" + URI.escape(opt.widget.selected_text(opt.messages.first)).to_s) end

  command(:open_link,
          name: 'リンクを開く',
          condition: Plugin::Command[:HasOneMessage] & lambda{ |opt|
            opt.messages[0].entity.to_a.any? {|u| u[:slug] == :urls } },
          visible: true,
          role: :timeline) do |opt|
    opt.messages[0].entity.to_a.each {|u|
      ::Gtk::TimeLine.openurl(u[:url]) if u[:slug] == :urls } end

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
            opt.widget.deletable },
          visible: true,
          icon: Skin.get("close.png"),
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
          condition: lambda{ |opt|
            if opt.widget.respond_to? :active_chain
              not opt.widget.active_chain.last.is_a? Plugin::GUI::Postbox
            else
              opt.widget.is_a? Plugin::GUI::Postbox end },
          visible: false,
          role: :window) do |opt|
    focus_move_to_nearest_postbox(opt.widget.active_chain.last)
  end

  command(:focus_to_tab,
          name: 'タブにフォーカス',
          condition: lambda{ |opt| true },
          visible: false,
          role: :postbox) do |opt|
    focus_move_to_latest_widget(opt.widget)
  end

  command(:timeline_scroll_to_top,
          name: 'タイムラインの一番上にジャーンプ！',
          condition: lambda{ |opt| true },
          visible: false,
          role: :timeline) do |opt|
    opt.widget.scroll_to_top end

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
      notice "activate #{term} #{widget.class} #{term.class}"
      src_tl = widget.active_chain.last
      if widget.is_a?(Plugin::GUI::Pane) and src_tl.is_a?(Plugin::GUI::Timeline) and term.is_a?(Plugin::GUI::Timeline)
        slide_timeline_focus(src_tl, term) end end end

  # タイムライン _src_ で選択されているディスプレイ上のy座標が同じ _dest_ のツイートに
  # フォーカスを移動する
  # ==== Args
  # [src] フォーカスを取得するタイムライン
  # [dest] フォーカスを設定するタイムライン
  def slide_timeline_focus(src, dest)
    type_strict src => Plugin::GUI::Timeline, dest => Plugin::GUI::Timeline
    y = Plugin.filtering(:gui_timeline_cursor_position, src, nil).last
    notice "y = #{y}"
    if y
      Plugin.call(:gui_timeline_move_cursor_to, dest, y) end end

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

  # 最後にアクティブだったペインにフォーカスを与える。
  # 親タイムラインがあれば、それにフォーカスを与える。
  # ==== Args
  # [postbox] 基準となるウィジェット
  def focus_move_to_latest_widget(postbox)
    if postbox.parent.is_a? Plugin::GUI::Window
      pane = last_active_pane[postbox.parent.slug]
      pane.active! if pane
    else
      postbox.parent.active! end end

  def last_active_pane
    @last_active_pane ||= {} end

end
