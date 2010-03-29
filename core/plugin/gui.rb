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
        @window = self.gen_window()
        container = Gtk::VBox.new(false, 0)
        mumbles = Gtk::VBox.new(false, 0)
        postbox = Gtk::PostBox.new(watch, :postboxstorage => mumbles)
        mumbles.pack_start(postbox)
        @window.set_focus(postbox.post)
        container.pack_start(mumbles, false)
        container.pack_start(self.book)
        @window.add(container)
        @window.show_all
      end
    end

    def onplugincall(watch, command, container, label)
      if(command == :mui_tab_regist) then
        self.regist_tab(container, label)
      end
    end

    def regist_tab(container, label)
      order = ['TL', 'Me', 'Se']
      @@mutex.synchronize{
        @book_children = [] if not(@book_children)
        Gtk::Lock.synchronize do
          idx = where_should_insert_it(label, @book_children, order)
          self.book.insert_page(idx, container, gen_label(label))
          self.book.show_all
        end
      }
    end

    def book()
      @@mutex.synchronize{
        Gtk::Lock.synchronize do
          if not(@book) then
            @book = Gtk::Notebook.new
            @book.set_tab_pos(Gtk::POS_RIGHT)
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
