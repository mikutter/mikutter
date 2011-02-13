# -*- coding: utf-8 -*-

Module.new do

  class << self

    def define_contextmenu(name, appear_condition=ret_nth, &proc)
      # Gtk::Mumble.contextmenu.registmenu(name, appear_condition, &proc)
      column = [name.freeze, appear_condition, proc].freeze
      Plugin.create(:contextmenu).add_event_filter(:contextmenu){ |menu|
        menu << column
        [menu]
      }
    end

  end

  define_contextmenu("コピー", lambda{ |m,w|
                       w.is_a?(Gtk::TextView) and
                       w.buffer.selection_bounds[2] }){ |this, w|
    w.copy_clipboard }

  define_contextmenu('本文をコピー', lambda{ |m,w|
                       Gtk::Mumble.get_active_mumbles.size == 1 and
                       w.is_a?(Gtk::TextView) and
                       not w.buffer.selection_bounds[2] }){ |this, w|
    w.select_all(true)
    w.copy_clipboard
    w.select_all(false) }

  define_contextmenu("返信", lambda{ |m,w| m.message.repliable? }){ |this, w|
    this.gen_postbox(this.message, :subreplies => Gtk::Mumble.get_active_mumbles) }

  define_contextmenu("全員に返信", lambda{ |m,w| m.message.repliable? }){ |this, w|
    this.gen_postbox(this.message,
                     :subreplies => this.message.ancestors,
                     :exclude_myself => true) }

  define_contextmenu("引用", lambda{ |m,w|
                       Gtk::Mumble.get_active_mumbles.size == 1 and
                       m.message.repliable? }){ |this, w|
    this.gen_postbox(this.message, :retweet => true) }

  define_contextmenu("公式リツイート", lambda{ |m,w|
                       m.message.repliable? and not m.message.from_me? }){ |this, w|
    Gtk::Mumble.get_active_mumbles.map{ |m| m.to_message }.uniq.select{ |m| not m.from_me? }.each{ |x| x.retweet } }

  delete_condition = lambda{ |m,w| Gtk::Mumble.get_active_mumbles.all?{ |e| e.message.from_me? } }

  define_contextmenu('削除', delete_condition){ |this, w|
    Gtk::Mumble.get_active_mumbles.each { |e|
      e.message.destroy if Gtk::Dialog.confirm("本当にこのつぶやきを削除しますか？\n\n#{e.message.to_show}") } }

  retweet_cancel_condition = lambda{ |m,w| Gtk::Mumble.get_active_mumbles.all?{ |e|
      e.message.service and e.message.retweeted_by.include?(e.message.service.user) } }

  define_contextmenu('リツイートをキャンセル', retweet_cancel_condition){ |this, w|
    Gtk::Mumble.get_active_mumbles.each { |e|
      retweet = e.message.retweeted_statuses.find{ |x| x.from_me? }
      retweet.destroy if retweet and Gtk::Dialog.confirm("このつぶやきのリツイートをキャンセルしますか？\n\n#{e.message.to_show}") } }

end
