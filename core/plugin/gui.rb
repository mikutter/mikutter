# -*- coding:utf-8 -*-
# Plugin/GUI
#

miquire :core, 'utils'
miquire :plugin, 'plugin'
miquire :mui
miquire :core, 'configloader'

require 'gtk2'
require 'singleton'
require 'monitor'

module Plugin
  class GUI
    include ConfigLoader

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
      @memo_color = memoize{ |r,g,b|
        Gtk::Lock.synchronize do
          c = Gdk::Color.new(r*255,g*255,b*255)
          Gdk::Colormap.system.alloc_color(c, false, true)
          c
        end
      }
    end

    def onboot(watch)
      Gtk::Lock.synchronize do
        self.statusbar.push(self.statusbar.get_context_id('hello'), "#{watch.user_by_cache}? みっくみくにしてやんよ")
        @window = self.gen_window()
        container = Gtk::VBox.new(false, 0)
        main = Gtk::HBox.new(false, 0)
        @paneshell = Gtk::HBox.new(false, 0)
        @pane = Gtk::HBox.new(true, 0)
        sidebar = Gtk::VBox.new(false, 0)
        mumbles = Gtk::VBox.new(false, 0)
        postbox = Gtk::PostBox.new(watch, :postboxstorage => mumbles, :delegate_other => true)
        mumbles.pack_start(postbox)
        @window.set_focus(postbox.post)
        UserConfig[:tab_order] = UserConfig[:tab_order].select{ |n| not n.empty? }
        UserConfig[:tab_order].size.times{ |cnt|
          @pane.pack_end(self.books(cnt)) }
        main.pack_start(@paneshell.pack_end(@pane)).closeup(sidebar)
        newpane
        @window.add(container.closeup(mumbles).pack_start(main).closeup(self.statusbar))
        set_icon
        @window.show_all
      end
    end

    def set_icon
      @window.icon = Gdk::Pixbuf.new(File.expand_path(MUI::Skin.get('icon.png')), 256, 256)
    end

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
        book.set_tab_pos(TABPOS[val]) }
      book.signal_connect('page-reordered'){
        UserConfig[:tab_order] = books_labels
        false }
      book.signal_connect('page-removed'){
        if book.children.empty? and book.parent
          UserConfig.disconnect(tab_position_hook_id)
          book.parent.remove(book) end
        Delayer.new{ UserConfig[:tab_order] = books_labels }
        false }
      book end

    def newpane
      book = gen_book.set_width_request(16)
      page_added = book.signal_connect('page-added'){
        book.signal_handler_disconnect(page_added)
        book.reparent(@pane)
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
          return book_id, index if book.get_menu_label(child).text == label } } end

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
        puts "#{label}: book#{book_id}"
        idx = where_should_insert_it(label, book_labels(book_id), order_in_book(book_id))
        tab_label = Gtk::EventBox.new.tooltip(label)
        if image.is_a?(String)
          tab_label.add(Gtk::WebIcon.new(image, 24, 24))
        else
          tab_label.add(Gtk::Label.new(label)) end
        tab_label.extend(TabButton).label = label
        books(book_id).insert_page_menu(idx, container, tab_label.show_all, Gtk::Label.new(label))
        books(book_id).set_tab_reorderable(container, true).set_tab_detachable(container, true)
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
        self.books(book_id).remove_page(index) end end

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
          Gtk::Lock.synchronize do
            Gtk.main_quit
          end
          false
        }
        window.signal_connect("expose_event"){ |window, event|
          Gtk::Lock.synchronize do
            if(window.realized?) then
              new_size = window.window.geometry[2,2]
              if(size != new_size) then
                this.store(:size, new_size)
                size = new_size
              end
              new_position = window.position
              if(position != new_position) then
                this.store(:position, new_position)
                position = new_position
              end
            end
          end
          false
        }
        window
      end
    end

    def color(r, g, b)
      @memo_color.call(r, g, b)
    end
  end

end

# プラグインの登録
gui = Plugin::GUI.new
plugin = Plugin::create(:gui)
plugin.add_event(:boot, &gui.method(:onboot))

# タブを登録
# (Widget container, String label[, String iconpath])
plugin.add_event(:mui_tab_regist, &gui.method(:regist_tab))

plugin.add_event(:mui_tab_remove, &gui.method(:remove_tab))

plugin.add_event(:mui_tab_active, &gui.method(:on_mui_tab_active))

plugin.add_event(:apilimit){ |time|
  Plugin.call(:update, nil, [Message.new(:message => "Twitter APIの制限数を超えたので、#{time.strftime('%H:%M')}までアクセスが制限されました。この間、タイムラインの更新などが出来ません。",
                                        :system => true)])
  gui.statusbar.push(gui.statusbar.get_context_id('system'), "Twitter APIの制限数を超えました。#{time.strftime('%H:%M')}に復活します") }

plugin.add_event(:apifail){ |errmes|
  gui.statusbar.push(gui.statusbar.get_context_id('system'), "Twitter サーバが応答しません(#{errmes})") }

api_limit = {:ip_remain => '-', :ip_time => '-', :auth_remain => '-', :auth_time => '-'}
plugin.add_event(:apiremain){ |remain, time, transaction|
  api_limit[:auth_remain] = remain
  api_limit[:auth_time] = time.strftime('%H:%M')
  gui.statusbar.push(gui.statusbar.get_context_id('system'), "API auth#{api_limit[:auth_remain]}回くらい (#{api_limit[:auth_time]}まで) IP#{api_limit[:ip_remain]}回くらい (#{api_limit[:ip_time]}まで)") }

plugin.add_event(:ipapiremain){ |remain, time, transaction|
  api_limit[:ip_remain] = remain
  api_limit[:ip_time] = time.strftime('%H:%M')
  gui.statusbar.push(gui.statusbar.get_context_id('system'), "API auth#{api_limit[:auth_remain]}回くらい (#{api_limit[:auth_time]}まで) IP#{api_limit[:ip_remain]}回くらい (#{api_limit[:ip_time]}まで)") }

plugin.add_event(:rewindstatus){ |mes|
  gui.statusbar.push(gui.statusbar.get_context_id('system'), mes) }

miquire :addon, 'addon'
