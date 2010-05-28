#
# Plugin/GUI
#

miquire :core, 'utils'
miquire :plugin, 'plugin'
miquire :mui

require 'gtk2'
require 'singleton'
require 'monitor'

module Plugin
  class GUI < Plugin

    class TabButton < Gtk::Button
      include Comparable
      attr_accessor :pane, :label

      def ==(other)
        @label == other.to_s end

      def to_s
        @label end

      def <=>(other)
        @label <=> other.to_s end
    end

    @@mutex = Monitor.new

    def initialize
      @memo_color = memoize{ |r,g,b|
        Gtk::Lock.synchronize do
          c = Gdk::Color.new(r*255,g*255,b*255)
          Gdk::Colormap.system.alloc_color(c, false, true)
          c
        end
      }
    end

    def onboot(watch)
      self._onboot(watch)
    end

    def _onboot(watch)
      Gtk::Lock.synchronize do
        self.statusbar.push(self.statusbar.get_context_id('hello'), "#{watch.user}? みっくみくにしてやんよ")
        @window = self.gen_window()
        container = Gtk::VBox.new(false, 0)
        main = Gtk::HBox.new(false, 0)
        @pane = Gtk::HBox.new(true, 0)
        sidebar = Gtk::VBox.new(false, 0)
        mumbles = Gtk::VBox.new(false, 0)
        postbox = Gtk::PostBox.new(watch, :postboxstorage => mumbles)
        mumbles.pack_start(postbox)
        @window.set_focus(postbox.post)
        @pane.pack_end(self.book)
        main.pack_start(@pane)
        sidebar.pack_start(self.tab, false)
        main.pack_start(sidebar, false)
        container.pack_start(mumbles, false)
        container.pack_start(main)
        container.pack_start(self.statusbar, false)
        @window.add(container)
        set_icon
        @window.show_all
      end
    end

    def set_icon
      @window.icon = Gdk::Pixbuf.new(File.expand_path(MUI::Skin.get('icon.png')), 256, 256)
    end

    def onplugincall(watch, command, *args)
      case command
      when :mui_tab_regist:
          self.regist_tab(*args)
      when :mui_tab_remove:
          self.remove_tab(*args)
      when :mui_tab_active:
          index = @book_children.index(args[0])
          if index
            self.book.set_page(index)
          end
      when :apilimit:
          Ring::fire(:update, [watch, Message.new(:message => "Twitter APIの制限数を超えたので、#{args[0].strftime('%H:%M')}までアクセスが制限されました。この間、タイムラインの更新などが出来ません。",
                                                  :system => true)])
          self.statusbar.push(self.statusbar.get_context_id('system'), "Twitter APIの制限数を超えました。#{args[0].strftime('%H:%M')}に復活します")
      when :apifail:
          self.statusbar.push(self.statusbar.get_context_id('system'), "Twitter サーバが応答しません(#{args[0]})")
      when :apiremain:
          self.statusbar.push(self.statusbar.get_context_id('system'), "API あと#{args[0]}回くらい (#{args[1].strftime('%H:%M')}まで)")
      when :rewindstatus:
          self.statusbar.push(self.statusbar.get_context_id('system'), args[0])
      end
    end

    def statusbar
      if not defined? @statusbar then
        @statusbar = Gtk::Statusbar.new
        @statusbar.has_resize_grip = true
      end
      @statusbar
    end

    def gen_tabbutton(container, label, image=nil)
      widget =TabButton.new
      Gtk::Tooltips.new.set_tip(widget, label, nil)
      widget.pane = container
      widget.label = label
      widget.add((image or gen_label(label)))
      widget.signal_connect('clicked'){ |w|
        Gtk::Lock.synchronize{
          index = @book_children.index(w.label)
          self.book.page = index if index }
        false }
      widget.signal_connect('key_press_event'){ |w, event|
        Gtk::Lock.synchronize{
          case event.keyval
          when 65361:
              index = @book_children.index(w.label)
            if index then
              self.book.remove_page(index)
              @book_children.delete_at(index)
              @pane.pack_end(w.pane)
            end
          when 65363:
              if not @book_children.index(w.label) then
                @pane.remove(w.pane)
                self.book.append_page(w.pane)
                @book_children << w.label end end }
        true }
      widget end

    def regist_tab(container, label, image=nil)
      default_active = 'TL'
      order = ['TL', 'Me', 'Search', 'Se']
      @@mutex.synchronize{
      @book_children = [] if not(@book_children)
        Gtk::Lock.synchronize{
          idx = where_should_insert_it(label, @book_children, order)
          self.book.insert_page(idx, container, gen_label(label))
          @book_children.insert(idx, label)
          self.tab.pack(gen_tabbutton(container, label, image).show_all, false)
          container.show_all } } end

    def remove_tab(label)
      index = @book_children.index(label)
      if index
        self.book.remove_page(index)
        self.tab.remove(self.tab.children.find{ |node| node.label == label }) end end

    def tab
      Gtk::Lock.synchronize do
        if not(defined? @tabbar) then
          order = ['TL', 'Me', 'Search', 'Se']
          @tabbar = Gtk::PriorityVBox.new(false, 0){ |w, tabbar|
            -( @book_children.index(w.label) )
          } end end
      @tabbar end

    def book()
      @@mutex.synchronize{
        Gtk::Lock.synchronize do
          if not(@book) then
            @book = Gtk::Notebook.new
            @book.set_tab_pos(Gtk::POS_RIGHT)
            @book.set_show_tabs(false)
          end
        end
      }
      return @book
    end

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
        #window.set_app_paintable(true)
        #window.realize
        #self.background(window)
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
Plugin::Ring.push Plugin::GUI.new,[:boot, :plugincall]

miquire :addon, 'addon'
