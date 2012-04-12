# -*- coding:utf-8 -*-
# Plugin/GUI
#

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'utils'))
miquire :core, 'plugin'
miquire :core, 'configloader'
miquire :miku, 'miku'
miquire :mui, 'postbox'

require 'gtk2'
require 'singleton'
require 'monitor'

class Plugin
  class GUI
    include ConfigLoader

    REQUIRE_RUBYGTK_VERSION = [1,0,0]
    REQUIRE_RUBY_VERSION = [1,9,2]

    module TabButton
      include Comparable
      attr_accessor :label

      def ==(other)
        @label == other.to_s end

      def to_s
        @label end

      def <=>(other)
        @label <=> other.to_s end
    end

    @@mutex = Monitor.new

    def initialize
      @tab_log = ['Home Timeline']
    end

    def color(r, g, b)
      Gtk::Lock.synchronize do
        c = Gdk::Color.new(r*255,g*255,b*255)
        Gdk::Colormap.system.alloc_color(c, false, true)
        c
      end
    end
    memoize :color

    def version_check(name, require, now)
      if((now <=> require) < 0)
        if Mopt.skip_version_check
          Plugin.activity :system, "#{name}のバージョンが古すぎます(#{require.join('.')}以降が必要、現在#{now.join('.')})。\n問題が起こるかもしれません。更新してください。"
        else
          chi_fatal_alert("#{name}のバージョンが古すぎます"+
                          "(#{require.join('.')}以降が必要、現在#{now.join('.')})。\n"+
                          "どうしても起動したい人は、--skip-version-checkをつけて起動してください。") end end end

    def onboot(watch)
      version_check('Ruby', REQUIRE_RUBY_VERSION, RUBY_VERSION_ARRAY)
      version_check('RubyGnome2', REQUIRE_RUBYGTK_VERSION, Gtk::BINDING_VERSION)

      self.statusbar.push(self.statusbar.get_context_id('hello'), "#{watch.user_by_cache}? みっくみくにしてやんよ")
      @window = self.gen_window()
      container = Gtk::VBox.new(false, 0)
      main = Gtk::HBox.new(false, 0)
      @paneshell = Gtk::HBox.new(false, 0)
      @pane = Gtk::HBox.new(true, 0)
      sidebar = Gtk::VBox.new(false, 0)
      @prompt = Gtk::VBox.new(false, 0)
      postbox = Gtk::PostBox.new(watch, :postboxstorage => postboxes, :delegate_other => true)
      postboxes.pack_start(postbox)
      @window.set_focus(postbox.post)
      UserConfig[:tab_order] = UserConfig[:tab_order].select{ |n| not n.empty? }
      UserConfig[:tab_order].size.times{ |cnt|
        @pane.pack_end(self.books(cnt)) }
      main.pack_start(@paneshell.pack_end(@pane)).closeup(sidebar)
      newpane
      @window.add(container.closeup(postboxes).pack_start(main).closeup(@prompt).closeup(statusbar))
      set_icon
      @window.signal_connect(:key_press_event){ |widget, event|
        Plugin.call(:keypress, Gtk.keyname([event.keyval ,event.state]))
        if Gtk.keyname([event.keyval ,event.state]) == 'Alt + x'
          input = ExecuteBox.new(Executer.new(watch), :delegate_other => false)
          @prompt.add(input).show_all
          input.active
          true
        end
      }
      @window.show_all
    end

    # メインのツイートのpostboxを格納するVBoxを返す
    def postboxes
      @postboxes ||= Gtk::VBox.new(false, 0) end

    def set_icon
      @window.icon = Gdk::Pixbuf.new(File.expand_path(MUI::Skin.get('icon.png')), 256, 256)
    end

    # _tab_ タブのラベル(String)
    # ラベル _tab_ のついたタブをアクティブにします。
    def on_mui_tab_active(tab)
      book_id, index = get_tabindex(tab)
      self.books(book_id).set_page(index) if index
    end

    def statusbar
      if not defined? @statusbar then
        @statusbar = Gtk::Statusbar.new
        @statusbar.has_resize_grip = true
      end
      @statusbar
    end

    TABPOS = [Gtk::POS_TOP, Gtk::POS_BOTTOM, Gtk::POS_LEFT, Gtk::POS_RIGHT]
    def gen_book
      book = Gtk::Notebook.new.set_tab_pos(TABPOS[UserConfig[:tab_position]]).set_tab_border(0).set_group_id(0).set_scrollable(true)
      tab_position_hook_id = UserConfig.connect(:tab_position){ |key, val, before_val, id|
        notice "change tab pos to #{TABPOS[val]}"
        book.set_tab_pos(TABPOS[val]) }
      book.signal_connect('page-reordered'){
        UserConfig[:tab_order] = books_labels
        false }
      book.signal_connect('page-removed'){
        Delayer.new{
          unless book.destroyed?
            if book.children.empty? and book.parent
              UserConfig.disconnect(tab_position_hook_id)
              book.parent.remove(book) end
            UserConfig[:tab_order] = books_labels end }
        false }
      book end

    def newpane
      book = gen_book.set_width_request(16)
      page_added = book.signal_connect('page-added'){
        book.signal_handler_disconnect(page_added)
        # book.reparent(@pane)
        book.parent.remove(book)
        @pane.pack_end(book)
        @books << book
        UserConfig[:tab_order] = books_labels
        newpane
        false }
      @paneshell.pack_end(book, false).show_all
    end

    def books(page = nil)
      Gtk::Lock.synchronize do
        @books = [] if not(@books)
        if page === nil
          return @books
        elsif not @books[page]
          @books[page] = gen_book end end
      @books[page] end

    def get_tabindex(label)
      books.each_with_index{ |book, book_id|
        book.children.each_with_index{ |child, index|
          return book_id, index if book.get_menu_label(child).text == label } }
      nil end

    def books_labels
      books.map{ |book|
        book.children.map{ |child|
          book.get_menu_label(child).text } } end

    def book_labels(book_id)
      books(book_id).children.map{ |child|
        books(book_id).get_menu_label(child).text } end

    def belong_book(label)
      UserConfig[:tab_order].each_with_index{ |labels, index|
        return index if labels.include?(label) }
      nil end

    def order_in_book(book_id)
      UserConfig[:tab_order][book_id] end

    def regist_tab(container, label, image=nil)
      default_active = 'Home Timeline'
      Gtk::Lock.synchronize{
        book_id = (belong_book(label) or 0)
        idx = where_should_insert_it(label, book_labels(book_id), order_in_book(book_id))
        tab_label = Gtk::EventBox.new.tooltip(label)
        if image.is_a?(String)
          tab_label.add(Gtk::WebIcon.new(image, 24, 24))
        elsif image.is_a?(Gtk::Image)
          tab_label.add(image)
        else
          tab_label.add(Gtk::Label.new(label)) end
        tab_label.extend(TabButton).label = label
        books(book_id).insert_page_menu(idx, container, tab_label.show_all, Gtk::Label.new(label))
        books(book_id).set_tab_reorderable(container, true).set_tab_detachable(container, true)
        Delayer.new{ books(book_id).set_page(idx) } if idx == 0
        @tab_log.push(label)
        container.show_all } end

    def focus_before_tab(label)
      @tab_log.delete(label)
      book_id, idx = get_tabindex(@tab_log.first)
      self.books(book_id).set_page(idx)
    end

    def remove_tab(label)
      book_id, index = get_tabindex(label)
      if index
        focus_before_tab(label)
        child = self.books(book_id).get_nth_page(index)
        self.books(book_id).remove_page(index)
        child.destroy end end

    def gen_toolbar(posts, watch)
      Gtk::Lock.synchronize do
        toolbar = Gtk::Toolbar.new
        toolbar.append('つぶやく', nil, nil,
                       Gtk::Image.new(Gdk::Pixbuf.new('data/icon.png', 24, 24))){
          container = Gtk::PostBox.new(watch)
          posts.pack_start(container)
          posts.show_all
          @window.set_focus(container.post)
        }
        toolbar
      end
    end

    def gen_label(msg)
      Gtk::Lock.synchronize do
        label = Gtk::Label.new
        label.markup = msg
        label
      end
    end

    def background(window)
      Gtk::Lock.synchronize do
        draw = window.window
        #window.signal_connect("expose_event") do |win, evt|
        #  self.miracle_painting(draw, [64, 128, 255], [64, 224, 224])
        #end
      end
    end

    # miracle painting, miracle show time!
    def miracle_painting(draw, start, finish)
      Gtk::Lock.synchronize do
        gc = Gdk::GC.new(draw)
        geo = draw.geometry
        geo[3].times{ |y|
          c = [0, 1, 2].map{ |count|
            (finish[count] - start[count]) *([1, y].max) / geo[3] + start[count]
          }
          gc.set_foreground(color(*c))
          draw.draw_line(gc, 0, y, geo[2], y)
        }
      end
    end

    def gen_window()
      Gtk::Lock.synchronize do
        window = Gtk::Window.new
        window.title = Environment::NAME
        window.set_size_request(240, 240)
        size = at(:size, [Gdk.screen_width/3, Gdk.screen_height*4/5])
        position = at(:position, [Gdk.screen_width - size[0], Gdk.screen_height/2 - size[1]/2])
        window.set_default_size(*size)
        window.move(*position)
        this = self
        window.signal_connect("destroy"){
          Delayer.freeze
          window.destroy
          Gtk::Object.main_quit
          # Gtk.main_quit
          false }
        window.signal_connect("expose_event"){ |window, event|
          if(window.realized?)
            new_size = window.window.geometry[2,2]
            if(size != new_size)
              this.store(:size, new_size)
              size = new_size end
            new_position = window.position
            if(position != new_position)
              this.store(:position, new_position)
              position = new_position end end
          false }

        Plugin.create(:gui).add_event_filter(:get_windows){ |windows|
          windows = Set.new unless windows
          windows << window
          [windows] }
        last_store(window)
        window end end

    def last_store(window)
      last_controlled = Time.new
      window.ssc(:event){ |this, event|
        if not [Gdk::Event::Type::EXPOSE, Gdk::Event::Type::NO_EXPOSE].include?(event.event_type)
          last_controlled = Time.new end
        false }
      Plugin.create(:gui).add_event_filter(:get_idle_time){ |time|
        [(time or (Time.new - last_controlled))] } end

  end

  class ExecuteBox < Gtk::PostBox
    def add_footer?
      false end end

  class Executer
    @@toplevel = MIKU::SymbolTable.new.run_init_script

    def initialize(service)
      @@toplevel.bind(:service, service, :setcar)
      @service = service end

    def service
      self end

    def post(args)
      yield(:start, nil)
      result = nil
      begin
        # result = miku(MIKU.parse(args[:message].to_s), @@toplevel)
        result = eval(args[:message].to_s)
        yield(:success, result)
      rescue Exception, RuntimeError=> e
        result = e
        yield(:fail, e) end
      Plugin.call(:update, nil, [Message.new(:message => result.inspect,
                                             :replyto => Message.new(:message => args[:message].to_s,
                                                                     :system => true),
                                             :system => true)]) end end

end

# プラグインの登録
gui = Plugin::GUI.new
plugin = Plugin::create(:gui)
plugin.add_event(:boot, &gui.method(:onboot))
plugin.add_event_filter(:main_postbox){ |postbox| [gui.postboxes] }

# タブを登録
# (Widget container, String label[, String iconpath])
plugin.add_event(:mui_tab_regist, &gui.method(:regist_tab))

plugin.add_event(:mui_tab_remove, &gui.method(:remove_tab))

plugin.add_event(:mui_tab_active, &gui.method(:on_mui_tab_active))

plugin.add_event(:apilimit, &tclambda(Time){ |time|
                   Plugin.activity :system, "Twitter APIの制限数を超えたので、#{time.strftime('%H:%M')}までアクセスが制限されました。この間、タイムラインの更新などが出来ません。"
                   gui.statusbar.push(gui.statusbar.get_context_id('system'), "Twitter APIの制限数を超えました。#{time.strftime('%H:%M')}に復活します") })

plugin.add_event(:apifail){ |errmes|
  gui.statusbar.push(gui.statusbar.get_context_id('system'), "Twitter サーバが応答しません(#{errmes})") }

api_limit = {:ip_remain => '-', :ip_time => '-', :auth_remain => '-', :auth_time => '-'}
plugin.add_event(:apiremain,
                 &tclambda(Integer, Time){ |remain, time|
                   api_limit[:auth_remain] = remain
                   api_limit[:auth_time] = time.strftime('%H:%M')
                   gui.statusbar.push(gui.statusbar.get_context_id('system'), "API auth#{api_limit[:auth_remain]}回くらい (#{api_limit[:auth_time]}まで) IP#{api_limit[:ip_remain]}回くらい (#{api_limit[:ip_time]}まで)") })

plugin.add_event(:ipapiremain,
                 &tclambda(Integer, Time){ |remain, time|
                   api_limit[:ip_remain] = remain
                   api_limit[:ip_time] = time.strftime('%H:%M')
                   gui.statusbar.push(gui.statusbar.get_context_id('system'), "API auth#{api_limit[:auth_remain]}回くらい (#{api_limit[:auth_time]}まで) IP#{api_limit[:ip_remain]}回くらい (#{api_limit[:ip_time]}まで)") })

plugin.add_event(:rewindstatus){ |mes|
  gui.statusbar.push(gui.statusbar.get_context_id('system'), mes) }
