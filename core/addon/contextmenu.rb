# -*- coding: utf-8 -*-

Module.new do

  class << self

    # argsの例
    # {
    #   :condition => (===でPoseudoMessageのインスタンスかnilと比較される。このコマンドをつかえるならtrueを返す)
    #   :exec => (実行内容。callメソッドが呼ばれる)
    #   :name => コマンドの名前。文字列。
    #   :description => コマンドの説明。
    #   :visible => 真理値。コンテキストメニューに表示するかどうかのフラグ
    #   :icon => アイコン。Gdk::Pixbufかファイル名をStringで
    #   :role => 実行できる環境の配列。以下のうちの何れか1つ
    #            :message           messageを右クリックしたとき(単数)
    #            :messages          messageが選択された時(配列で複数個)
    #            :message_select    messageのテキストが選択されたとき(単数)
    #            :timeline          タイムラインを右クリックしたとき
    #            :postbox           つぶやき入力ウィンドウ
    # }
    def define_command(slug, args)
      type_strict args => Hash
      args[:slug] = slug.to_sym
      args.freeze
      Plugin.create(:contextmenu).add_event_filter(:command){ |menu|
        menu[slug] = args
        [menu]
      }
    end

  end

  ROLE_MESSAGE = :message
  ROLE_MESSAGES = :messages
  ROLE_MESSAGE_SELECTED = :message_select
  ROLE_TIMELINE = :timeline
  ROLE_POSTBOX = :postbox

  define_command(:copy_selected_region,
                 :name => 'コピー',
                 :condition => lambda{ |m| true },
                 :exec => lambda{ |opt|
                   Gtk::Clipboard.copy(opt.message.entity.to_s[opt.miraclepainter.textselector_range]) },
                 :visible => true,
                 :role => ROLE_MESSAGE_SELECTED )

  define_command(:copy_description,
                 :name => '本文をコピー',
                 :condition => lambda{ |opt| Gtk::TimeLine.get_active_mumbles.size == 1 },
                 :exec => lambda{ |opt| Gtk::Clipboard.copy(opt.message.to_show) },
                 :visible => true,
                 :role => ROLE_MESSAGE )

  define_command(:reply,
                 :name => '返信',
                 :condition => lambda{ |ms| ms.map(&:message).all? &:repliable? },
                 :exec => lambda{ |ms| ms.first.timeline.reply(ms.first.message, :subreplies => ms.map(&:message)) },
                 :visible => true,
                 :role => ROLE_MESSAGES )

  define_command(:reply_all,
                 :name => '全員に返信',
                 :condition => lambda{ |ms| ms.map(&:message).all? &:repliable? },
                 :exec => lambda{ |ms|ms.first.timeline.reply(ms.first.message,
                                                              :subreplies => ms.map{ |m| m.message.ancestors }.flatten,
                                                              :exclude_myself => true) },
                 :visible => true,
                 :role => ROLE_MESSAGES )

  define_command(:legacy_retweet,
                 :name => '引用',
                 :condition => lambda{ |m| m.message.repliable? },
                 :exec => lambda{ |m| m.timeline.reply(m.message, :retweet => true) },
                 :visible => true,
                 :role => ROLE_MESSAGE )

  define_command(:retweet,
                 :name => 'リツイート',
                 :condition => lambda{ |ms|
                   ms.all?{ |m|
                     m.message.retweetable? and not m.message.retweeted_by_me? } },
                 :exec => lambda{ |ms| ms.map(&:message).select{ |x| not x.from_me? }.each(&:retweet) },
                 :visible => true,
                 :role => ROLE_MESSAGES )

  define_command(:delete_retweet,
                 :name => 'リツイートをキャンセル',
                 :condition => lambda{ |ms|
                   ms.all?{ |e|
                     e.message.retweetable? and e.message.retweeted_by_me? } },
                 :exec => lambda{ |ms|
                   ms.each { |e|
                     retweet = e.message.retweeted_statuses.find{ |x| x.from_me? }
                     retweet.destroy if retweet and Gtk::Dialog.confirm("このつぶやきのリツイートをキャンセルしますか？\n\n#{e.message.to_show}") } },
                 :visible => true,
                 :role => ROLE_MESSAGES )

  define_command(:favorite,
                 :name => 'ふぁぼふぁぼする',
                 :condition => lambda{ |ms| ms.map(&:message).all?{ |m| m.favoritable? and not m.favorited_by_me? } },
                 :exec => lambda{ |ms| ms.map(&:message).each{ |m| m.favorite(true)} },
                 :visible => true,
                 :role => ROLE_MESSAGES )

  define_command(:delete_favorite,
                 :name => 'ふぁぼをキャンセル',
                 :condition => lambda{ |ms| ms.all?{ |m| m.message.favorited_by_me? } },
                 :exec => lambda{ |ms| ms.each{ |m| m.message.favorite(false)} },
                 :visible => true,
                 :role => ROLE_MESSAGES )

  define_command(:delete,
                 :name => '削除',
                 :condition => lambda{ |ms| ms.all?{ |e| e.message.from_me? } },
                 :exec => lambda{ |ms|
                   ms.each { |e|
                     e.message.destroy if Gtk::Dialog.confirm("本当にこのつぶやきを削除しますか？\n\n#{e.message.to_show}") } },
                 :visible => true,
                 :role => ROLE_MESSAGES )

  define_command(:select_prev,
                 :name => 'ひとつ上のつぶやきを選択',
                 :condition => lambda{ |tl| true },
                 :exec => lambda{ |tl|
                   path, column = tl.cursor
                   tl.set_cursor(path, column, false) if path and column and path.prev! },
                 :visible => false,
                 :role => ROLE_TIMELINE )

  define_command(:select_next,
                 :name => 'ひとつ下のつぶやきを選択',
                 :condition => lambda{ |tl| true },
                 :exec => lambda{ |tl|
                   path, column = tl.cursor
                   tl.set_cursor(path, column, false) if path and column and path.next! },
                 :visible => false,
                 :role => ROLE_TIMELINE )

  define_command(:post_it,
                 :name => '投稿する',
                 :condition => lambda{ |postbox| postbox.post.editable? },
                 :exec => :post_it.to_proc,
                 :visible => false,
                 :role => ROLE_POSTBOX )

  define_command(:google_search,
                 :name => 'ggrks',
                 :condition => lambda{ |m| true },
                 :exec => lambda{ |opt|
                   kamiya_google_search_word = opt.message.entity.to_s[opt.miraclepainter.textselector_range]
                   Gtk::openurl("http://www.google.co.jp/search?q=" + URI.escape(kamiya_google_search_word).to_s) },
                 :visible => true,
                 :role => ROLE_MESSAGE_SELECTED )

  define_command(:open_link,
                 :name => 'リンクを開く',
                 :condition => lambda{ |opt|
                   opt.message.entity.to_a.any? {|u|
                     u[:slug] == :urls } },
                 :exec => lambda{ |opt|
                   opt.message.entity.to_a.each {|u|
                     Gtk::openurl(u[:url]) if u[:slug] == :urls } },
                 :visible => true,
                 :role => ROLE_MESSAGE )
end
