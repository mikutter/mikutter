
miquire :mui, 'webicon'

require 'gtk2'
require 'time'
require 'uri'
require_if_exist 'Win32API'

module Gtk
  class Mumble < Gtk::EventBox

    DEFAULT_HEIGHT = 64

    @@buttons = {
      :reply => Gtk::WebIcon.new("core#{File::SEPARATOR}skin#{File::SEPARATOR}data#{File::SEPARATOR}reply.png", 24, 24),
      :retweet => Gtk::WebIcon.new("core#{File::SEPARATOR}skin#{File::SEPARATOR}data#{File::SEPARATOR}retweet.png", 24, 24),
      :fav => {
        false => Gtk::WebIcon.new("core#{File::SEPARATOR}skin#{File::SEPARATOR}data#{File::SEPARATOR}fav.png", 24, 24),
        true => Gtk::WebIcon.new("core#{File::SEPARATOR}skin#{File::SEPARATOR}data#{File::SEPARATOR}unfav.png", 24, 24) },
      :etc => Gtk::WebIcon.new("core#{File::SEPARATOR}skin#{File::SEPARATOR}data#{File::SEPARATOR}etc.png", 24, 24)
    }

    def initialize(message)
      @message = message
      super()
      gen_mumble(message)
      self.border_width = 0
    end

    def get_backgroundcolor
      if(@message.from_me?) then
        [255,255,222]
      elsif(@message.to_me?) then
        [255,222,222]
      else
        [255,255,255]
      end
    end

    def gen_body(message, tags={})
      Lock.synchronize{
        buffer = Gtk::TextBuffer.new
        body = Gtk::TextView.new(buffer)
        msg = message.to_s
        if tags then
          buffer.create_tag('shell', tags)
          buffer.insert(body.buffer.start_iter, msg, 'shell')
        else
          buffer.insert(body.buffer.start_iter, msg)
        end
        msg.each_matches(URI.regexp(['http','https'])){ |match, index|
          index = msg[0, index].split(//u).size
          tag = buffer.create_tag(match, 'foreground' => 'blue', "underline" => Pango::UNDERLINE_SINGLE)
          tag.signal_connect('event'){ |this, textview, event, iter|
            Lock.synchronize{
              if(event.is_a?(Gdk::EventButton)) and
                  (event.button == 1) and
                  (event.event_type == Gdk::Event::BUTTON_RELEASE) and
                  not(textview.buffer.selection_bounds[2]) then
                self.open_url_with_browser(match)
              elsif(event.is_a?(Gdk::EventMotion)) then
                body.get_window(Gtk::TextView::WINDOW_TEXT).set_cursor(Gdk::Cursor.new(Gdk::Cursor::HAND2))
                body.show_all
              end
            }
            false
          }
          buffer.apply_tag(tag,
                           buffer.get_iter_at_offset(index),
                           buffer.get_iter_at_offset(index + match.split(//u).size))
        }
        body.editable = false
        body.cursor_visible = false
        body.wrap_mode = Gtk::TextTag::WRAP_CHAR
        body.signal_connect('realize'){ |body|
          Lock.synchronize{
            window = body.get_window(Gtk::TextView::WINDOW_TEXT)
            c = Gdk::Color.new(*get_backgroundcolor.map{|a| a*255})
            Gdk::Colormap.system.alloc_color(c, false, true)
            window.background = c
          }
          false
        }
        body.signal_connect('event'){
          Lock.synchronize{
            body.get_window(Gtk::TextView::WINDOW_TEXT).set_cursor(Gdk::Cursor.new(Gdk::Cursor::XTERM))
            body.show_all
          }
          false
        }
        body.signal_connect('button_press_event'){ |widget, event|
          Gtk::Lock.synchronize{ event.button == 3 }
        }
        body.signal_connect('button_release_event'){ |widget, event|
          Gtk::Lock.synchronize do
            self.menu_pop(widget, @replies, message) if (event.button == 3)
          end
          false
        }
        return body
      }
    end

    def open_url_with_browser(url)
      if(defined? Win32API) then
        shellExecuteA = Win32API.new('shell32.dll','ShellExecuteA',%w(p p p p p i),'i')
        shellExecuteA.call(0, 'open', url, 0, 0, 1)
      else
        system("/etc/alternatives/x-www-browser #{url} &") || system("firefox #{url} &")
      end
    end

    def gen_minimumble(message)
      Lock.synchronize{
        control = Gtk::HBox.new(false, 8)
        body = gen_body(message, 'foreground' => 'blue', 'font' => "Sans 8")
        control.pack_start(Gtk::Alignment.new(0, 0.5, 0, 0).add(Gtk::WebIcon.new(self.april_fool(message[:user][:profile_image_url]), 24, 24)), false)
        control.pack_start(body)
      }
    end

    def gen_header(message)
      header = Gtk::HBox.new(false, 16)
      idname = Gtk::Label.new(message[:user][:idname])
      name = Gtk::Label.new(message[:user][:name])
      created = Gtk::Label.new(message[:created].strftime('%H:%M:%S'))
      idname.style = Gtk::Style.new.set_font_desc(Pango::FontDescription.new('Sans 10').set_weight(700))
      created.style = Gtk::Style.new.set_fg(Gtk::STATE_NORMAL, *[0x66,0x66,0x66].map{|n| n*255 })
      header.pack_start(Gtk::Alignment.new(0, 0.5, 0, 0).add(idname), false)
      header.pack_start(Gtk::Alignment.new(0, 0.5, 0, 0).add(name), false)
      header.pack_start(Gtk::Alignment.new(1, 0.5, 0, 0).add(created))
      return header
    end

    def gen_control(message)
      control = Gtk::HBox.new(false, 8)
      iconwindow = Gtk::IconOverButton.new
      iconwindow.set_size_request(48, 48)
      iconwindow.set_grid_size(2, 2)
      if(message.repliable?) then
        iconwindow.add(@@buttons[:reply]){ self.gen_postbox(@replies, message) }
        iconwindow.add(@@buttons[:retweet]){ self.gen_postbox(@replies, message, :retweet => true) }
      end
      iconwindow.add(@@buttons[:etc]){ self.menu_pop(iconwindow, @replies, message) }
      if message.favoriable? then
        iconwindow.add(@@buttons[:fav][message.favorite?], :always_show => message.favorite?){ |this, options|
          message.favorite(!message.favorite?).join
          options[:always_show] = message[:favorited] = !message.favorite?
          [@@buttons[:fav][message.favorite?], options]
        }
      end
      iconwindow.sub_button{ self.menu_pop(iconwindow, @replies, message) }
      iconwindow.set_buttonback("core#{File::SEPARATOR}skin#{File::SEPARATOR}data#{File::SEPARATOR}overbutton.png", "core#{File::SEPARATOR}skin#{File::SEPARATOR}data#{File::SEPARATOR}overbutton_mouseover.png")
      iconwindow.background = Gtk::WebIcon.new(self.april_fool(message[:user][:profile_image_url]))
      control.pack_start(Gtk::Alignment.new(0, 0, 0, 0).add(iconwindow), false)
      control.pack_start(gen_body(message))
      if(UserConfig[:show_cumbersome_buttons]) then
        control.pack_start(self.control_buttons(message), false)
      end
      return control
    end

    def control_buttons(message)
      container = Gtk::HBox.new(false, 4)
      reply = Gtk::Button.new
      retweet = Gtk::Button.new
      reply.add(Gtk::WebIcon.new("core#{File::SEPARATOR}skin#{File::SEPARATOR}data#{File::SEPARATOR}reply.png", 16, 16))
      retweet.add(Gtk::WebIcon.new("core#{File::SEPARATOR}skin#{File::SEPARATOR}data#{File::SEPARATOR}retweet.png", 16, 16))
      container.pack_start(reply, false)
      container.pack_start(retweet, false)
      reply.signal_connect('clicked'){ self.gen_postbox(@replies, message); false }
      retweet.signal_connect('clicked'){ self.gen_postbox(@replies, message, :retweet => true); false }
      return Gtk::VBox.new(false, 0).pack_start(container, false)
    end

    def gen_mumble(message)
      Lock.synchronize{
        self.set_width_request(1)
        self.set_height_request(DEFAULT_HEIGHT)
        showing = false
        last_set_config = nil
        self.signal_connect('expose_event'){
          if not(showing) or (self.relation_configure != last_set_config) then
            Lock.synchronize{
              self.children.each{ |w| self.remove(w) }
              shell = Gtk::VBox.new(false, 0)
              shell.border_width = 4
              container = Gtk::HBox.new(false, 0)
              @replies = Gtk::VBox.new(false, 0)
              mumble = Gtk::VBox.new(false, 0)
              mumble.add(self.gen_header(message))
              mumble.add(self.gen_control(message))
              reply = Gtk::VBox.new(false, 0)
              mumble.add(reply)
              Thread.new(reply, message){ |reply, msg|
                parent = msg.receive_message(UserConfig[:retrieve_force_mumbleparent])
                if(parent.is_a?(Message)) then
                  Delayer.new(Delayer::NORMAL, reply, parent){ |reply, parent|
                    Lock.synchronize{ reply.add(gen_minimumble(parent).show_all) }
                  }
                end
              }
              mumble.add(@replies)
              container.add(mumble)
              self.set_height_request(-1)
              shell.add(container)
              self.add(shell)
              self.show_all
            }
            last_set_config = self.relation_configure
            showing = true
          end
          false
        }
        self.signal_connect('realize'){
          style = Gtk::Style.new()
          background = self.get_backgroundcolor
          style.set_bg(Gtk::STATE_NORMAL, *background.map{|a| a*255})
          self.style = style
          false
        }
      }
    end

    def relation_configure
      [UserConfig[:show_cumbersome_buttons], UserConfig[:retrieve_force_mumbleparent]]
    end

    def gen_postbox(replies, message, options={})
      Lock.synchronize{
        postbox = Gtk::PostBox.new(message, options)
        replies.pack_start(postbox)
        replies.show_all
        postbox.post.get_ancestor(Gtk::Window).set_focus(postbox.post)
      }
    end

    def menu_pop(widget, replies, message)
      Lock.synchronize{
        menu = Gtk::Menu.new
        menu_column = []
        if widget.is_a?(Gtk::TextView) then
          if(widget.buffer.selection_bounds[2]) then
            menu_column << Gtk::MenuItem.new("コピー")
            menu_column.last.signal_connect('activate') { |w|
              widget.copy_clipboard
              false
            }
          else
            menu_column << Gtk::MenuItem.new("本文をコピー")
            menu_column.last.signal_connect('activate') { |w|
              widget.select_all(true)
              widget.copy_clipboard
              widget.select_all(false)
              false
            }
          end
        end
        if message.repliable? then
          menu_column << Gtk::MenuItem.new("返信")
          menu_column.last.signal_connect('activate') { |w|
            self.gen_postbox(replies, message)
            false
          }
          menu_column << Gtk::MenuItem.new("非公式リツイート")
          menu_column.last.signal_connect('activate') { |w|
            self.gen_postbox(replies, message, :retweet => true)
            false
          }
        end
        menu_column.each{|item| menu.append(item) }
        menu.attach_to_widget(widget) {|attach_widgt, mnu| notice "detaching" }
        menu.show_all
        menu.popup(nil, nil, 0, 0)
      }
    end

    def [](key)
      @message[key]
    end

    def april_fool(url)
      if Time.now.strftime('%m%d') == '0401' then
        "http://toshia.dip.jp/img/api/#{Digest::MD5.hexdigest(url)[0,1].downcase}.png"
      else
        url
      end
    end

  end

end
