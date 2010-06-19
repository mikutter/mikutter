require 'gtk2'
require 'thread'

module Gtk
  class PostBox < Gtk::EventBox

    attr_accessor :post, :send, :tool, :return_to_top

    @@ringlock = Mutex.new
    @@postboxes = []

    def initialize(watch, options = {})
      @posting = false
      @return_to_top = nil
      @options = options
      Lock.synchronize do
        super()
        @box = Gtk::HBox.new(false, 0)
        @post = Gtk::TextView.new
        post.wrap_mode = Gtk::TextTag::WRAP_CHAR
        post.border_width = 2
        @send = Gtk::Button.new('!')
        @tool = Gtk::Button.new('-')
        if @options[:delegated_by]
          post.buffer.text = @options[:delegated_by].post.buffer.text
          @options[:delegated_by].post.buffer.text = ''
        elsif(options[:retweet])
          post.buffer.text = " RT @"+watch.idname+": "+watch[:message]
          post.buffer.place_cursor(post.buffer.start_iter)
        elsif not(watch.is_a?(Post))
          post.buffer.text = '@'+watch.idname + ' ' + post.buffer.text end
        post.accepts_tab = false
        w_remain = Gtk::Label.new((140 - UserConfig[:footer].strsize - post.buffer.text.split(//u).size).to_s)
        send.sensitive = self.postable?
        send.signal_connect('clicked'){|button|
          Lock.synchronize do
            self.post_it(watch)
          end
          false
        }
        post.signal_connect('key_press_event'){ |widget, event|
          Lock.synchronize{
            if(widget.editable? and
               keyname([event.keyval, event.state]) == keyname(UserConfig[:mumble_post_key]))
              post_it(watch)
              true end } }
        post.signal_connect('key_release_event'){ |textview, event|
          Lock.synchronize do
            now = textview.buffer.text.strsize
            remain = 140 - UserConfig[:footer].strsize - now
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
        self_realize_id = signal_connect('realize'){
          sw = self.get_ancestor(Gtk::ScrolledWindow)
          if(sw) then
            @return_to_top = sw.vadjustment.value == 0 else
            @return_to_top = false end
          if @options[:delegated_by]
            post_it(watch) end
          signal_handler_disconnect(self_realize_id) }
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

    def start_post
      @posting = true
      post.editable = false
      [self, post, send, tool].compact.each{|widget| widget.sensitive = false }
    end

    def end_post
      @posting = false
      post.editable = true
      [self, post, send, tool].compact.each{|widget| widget.sensitive = true }
    end

    def delegate(watch)
      if(@options[:postboxstorage] and @options[:delegate_other])
        options = @options.clone
        options[:delegate_other] = false
        options[:delegated_by] = self
        @options[:postboxstorage].pack_start(Gtk::PostBox.new(watch, options)).show_all
        true end end

    def post_it(watch)
      if self.postable? then
        Lock.synchronize do
          if(@options[:postboxstorage])
            return if delegate(watch)
            if not @options[:delegated_by]
              postbox = Gtk::PostBox.new(watch, @options)
              @options[:postboxstorage].
                pack_start(postbox).
                show_all.
                get_ancestor(Gtk::Window).
                set_focus(postbox.post) end end
          start_post
          (@options[:retweet] ? watch.service : watch).post(:message => post.buffer.text + UserConfig[:footer]){ |event, msg|
            case event
            when :fail
              end_post
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

    def brothers
      Lock.synchronize{
        @options[:postboxstorage].children.find_all{|c| c.sensitive? } } end

    def lonely?
      brothers.size <= 1 end

    def is_destroyable?(post, watch)
      if(@options.has_key?(:postboxstorage))
        return false if lonely?
        self.post_is_empty?(post, watch)
      else
        true end end

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
