require 'gtk2'
require 'thread'

module Gtk
  class PostBox < Gtk::EventBox

    attr_accessor :post, :return_to_top

    @@ringlock = Mutex.new
    @@postboxes = []

    def initialize(watch, options = {})
      @posting = false
      @return_to_top = nil
      @options = options
      Lock.synchronize do
        super()
        @box = Gtk::HBox.new(false, 0)
        @post = post = Gtk::TextView.new
        post.wrap_mode = Gtk::TextTag::WRAP_CHAR
        post.border_width = 2
        send = Gtk::Button.new('!')
        tool = Gtk::Button.new('-')
        if(options[:retweet]) then
          post.buffer.text = " RT @"+watch.idname+": "+watch[:message]
          post.buffer.place_cursor(post.buffer.start_iter)
        elsif not(watch.is_a?(Post)) then
          post.buffer.text = '@'+watch.idname + ' ' + post.buffer.text
        end
        post.accepts_tab = false
        w_remain = Gtk::Label.new((140 - post.buffer.text.split(//u).size).to_s)
        send.sensitive = self.postable?
        send.signal_connect('clicked'){|button|
          Lock.synchronize do
            self.post_it(watch, post, send, tool)
          end
          false
        }
        post.signal_connect('key_press_event'){ |widget, event|
          Lock.synchronize do
            if(widget.editable?) then
              if(self.keyname([event.keyval, event.state]) == self.keyname(UserConfig[:mumble_post_key])) then
                self.post_it(watch, post, send, tool)
              end
            end
          end
          false
        }
        post.signal_connect('key_release_event'){ |textview, event|
          Lock.synchronize do
            now = textview.buffer.text.split(//u).size
            remain = 140 - now
            w_remain.set_text(remain.to_s)
            send.sensitive = self.postable?
            tool.sensitive = self.is_destroyable?(post, watch) if tool
          end
          false
        }
        is_focus_out = lambda{ |widget|
          Delayer.new(Delayer::NORMAL, @options){ |options|
            Lock.synchronize do
              if(not(options.has_key?(:postboxstorage)) and self.post_is_empty?(post, watch)) then
                self.destroy_if_necessary(post, watch, send, tool)
              end
            end
          }
        }
        post.signal_connect_after('focus_out_event'){ |widget,e| is_focus_out.call(widget); false }
        tool.signal_connect_after('focus_out_event'){ |widget,e| is_focus_out.call(widget); false }
        tool.signal_connect('event'){
          tool.sensitive = self.is_destroyable?(post, watch)
          false
        }
        tool.signal_connect('button_release_event'){
          Lock.synchronize do
            self.destroy_if_necessary(post, watch)
          end
          false
        }
        self.signal_connect('realize'){
          sw = self.get_ancestor(Gtk::ScrolledWindow)
          if(sw) then
            @return_to_top = sw.vadjustment.value == 0
          else
            @return_to_top = false
          end
        }
        @box.pack_start(tool, false)
        @box.pack_start(post)
        @box.pack_start(w_remain, false)
        @box.pack_start(send, false)
        self.add(@box)
        self.regist
      end
    end

    def keyname(key)
      if key.empty? then
        return '(割り当てなし)'
      else
        Gtk::Lock.synchronize do
          r = ""
          r << 'Control + ' if (key[1] & Gdk::Window::CONTROL_MASK) != 0
          r << 'Shift + ' if (key[1] & Gdk::Window::SHIFT_MASK) != 0
          r << 'Alt + ' if (key[1] & Gdk::Window::META_MASK) != 0
          r << 'Super + ' if (key[1] & Gdk::Window::SUPER_MASK) != 0
          r << 'Hyper + ' if (key[1] & Gdk::Window::HYPER_MASK) != 0
          return r + Gdk::Keyval.to_name(key[0])
        end
      end
    end

    def menu_pop(widget, event)
      Lock.synchronize do
        menu = Gtk::Menu.new
        delete = Gtk::MenuItem.new("この入力欄を削除")
        delete.signal_connect('activate') { |w|
          Lock.synchronize do
            p 'delete'
            self.destroy
          end
        }
        [delete].each{|item| menu.append(item) }
        menu.attach_to_widget(widget) {|*args| yield(*args) if defined? yield }
        menu.show_all
        menu.popup(nil, nil, 0, 0)
      end
    end

    def postable?
      Lock.synchronize do
        not(self.post.buffer.text.empty?) and (/[^\s]/ === self.post.buffer.text)
      end
    end

    def post_it(watch, post, *other_widgets)
      if self.postable? then
        Lock.synchronize do
          @posting = true
          post.editable = false
          if(@options[:postboxstorage]) then
            postbox = Gtk::PostBox.new(watch, @options)
            @options[:postboxstorage].pack_start(postbox)
            @options[:postboxstorage].show_all
            @options[:postboxstorage].get_ancestor(Gtk::Window).set_focus(postbox.post)
          end
          [self, post, *other_widgets].compact.each{|widget| widget.sensitive = false }
          watch.post(:message => post.buffer.text){ |event, msg|
            case event
            when :fail
              [self, post, *other_widgets].compact.each{|widget| widget.sensitive = true }
            when :success
              Delayer.new{ self.destroy }
            end
          }
        end
      end
    end

    def post_is_empty?(post, watch)
      Lock.synchronize do
        return true if (post.buffer.text == "")
        return true if (defined? watch[:user]) and (post.buffer.text == '@'+watch[:user][:idname] + ' ')
      end
      false
    end

    def is_destroyable?(post, watch)
      if(@options.has_key?(:postboxstorage))
        Lock.synchronize do
          if not(@options[:postboxstorage].children.find_all{|c| c.sensitive? }.size > 1) then
            return false
          end
        end
        return self.post_is_empty?(post, watch)
      end
      true
    end

    def destroy_if_necessary(post, watch, *related_widgets)
      if not([post, *related_widgets].compact.any?{ |w| w.focus? }) and
          is_destroyable?(post, watch)
      then
        self.destroy
        true
      end
    end

    def destroy
      @@ringlock.synchronize{
        Lock.synchronize do
          if self.parent then
            self.parent.remove(self)
            @@postboxes.delete(self)
          end
        end
      }
    end

    def posting?
      @posting
    end

    def regist
      @@ringlock.synchronize{
        @@postboxes << self
      }
    end

    def self.list
      return @@postboxes
    end

  end
end
