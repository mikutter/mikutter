# -*- coding:utf-8 -*-
require 'gtk2'
require 'thread'

module Gtk
  class PostBox < Gtk::EventBox

    attr_accessor :post, :send, :tool, :return_to_top

    @@ringlock = Mutex.new
    @@postboxes = []

    def self.list
      return @@postboxes
    end

    def initialize(watch, options = {})
      Lock.synchronize{
        @posting = false
        @return_to_top = nil
        @options = options
        @watch = watch
        super()
        signal_connect('parent-set'){
          if parent
            sw = get_ancestor(Gtk::ScrolledWindow)
            if(sw)
              @return_to_top = sw.vadjustment.value == 0
            else
              @return_to_top = false end
              post_it if @options[:delegated_by] end }
        add(generate_box)
        regist } end

    def posting?
      @posting end

    private

    def keyname(key)
      if key.empty?
        return '(割り当てなし)'
      else
        r = ""
        r << 'Control + ' if (key[1] & Gdk::Window::CONTROL_MASK) != 0
        r << 'Shift + ' if (key[1] & Gdk::Window::SHIFT_MASK) != 0
        r << 'Alt + ' if (key[1] & Gdk::Window::META_MASK) != 0
        r << 'Super + ' if (key[1] & Gdk::Window::SUPER_MASK) != 0
        r << 'Hyper + ' if (key[1] & Gdk::Window::HYPER_MASK) != 0
        return r + Gdk::Keyval.to_name(key[0]) end end

#     def menu_pop(widget, event)
#       menu = Gtk::Menu.new
#       delete = Gtk::MenuItem.new("つぶやきを削除")
#       delete.signal_connect('activate') { |w| destroy }
#       [delete].each{|item| menu.append(item) }
#       menu.attach_to_widget(widget) {|*args| yield(*args) if defined? yield }
#       menu.show_all
#       menu.popup(nil, nil, 0, 0) end

    def postable?
      not(@post.buffer.text.empty?) and (/[^\s]/ === @post.buffer.text) end

    def start_post
      Gtk::Lock.synchronize{
        @posting = true
        post.editable = false
        [post, send].compact.each{|widget| widget.sensitive = false }
        tool.sensitive = true } end

    def end_post
      Gtk::Lock.synchronize{
        @posting = false
        post.editable = true
        [post, send].compact.each{|widget| widget.sensitive = true } } end

    def delegate
      Gtk::Lock.synchronize{
        if(@options[:postboxstorage] and @options[:delegate_other])
          options = @options.clone
          options[:delegate_other] = false
          options[:delegated_by] = self
          @options[:postboxstorage].pack_start(Gtk::PostBox.new(@watch, options)).show_all
          true end } end

    def service
      (retweet? ? @watch.service : @watch) end

    def post_it
      Gtk::Lock.synchronize{
        if postable? then
          if(@options[:postboxstorage])
            return if delegate
            if not @options[:delegated_by]
              postbox = Gtk::PostBox.new(@watch, @options)
              @options[:postboxstorage].
                pack_start(postbox).
                show_all.
                get_ancestor(Gtk::Window).
                set_focus(postbox.post) end end
          text = post.buffer.text
          text += UserConfig[:footer] if add_footer?
          @post_thread = service.post(:message => text){ |event, msg|
            case event
            when :start
              Delayer.new{ start_post }
            when :fail
              Delayer.new{ end_post }
            when :success
              Delayer.new{ destroy } end } end } end

    def post_is_empty?
      @post.buffer.text == "" or
        (defined?(@watch[:user]) and
         @post.buffer.text == "@#{@watch[:user][:idname]} ") end
#       return true if (@post.buffer.text == "")
#       return true if (defined? @watch[:user]) and (@post.buffer.text == '@'+@watch[:user][:idname] + ' ')
#       false end

    def brothers
      if(@options[:postboxstorage])
        Gtk::Lock::synchronize{
          @options[:postboxstorage].children.find_all{|c| c.sensitive? } }
      else
        [] end end

    def lonely?
      brothers.size <= 1 end

    def destructible?
      if(@options.has_key?(:postboxstorage))
        return false if lonely? or (brothers - [self]).any?{ |w| w.posting? }
        post_is_empty?
      else
        true end end

    def destroy_if_necessary(*related_widgets)
      Gtk::Lock::synchronize{
        if not([@post, *related_widgets].compact.any?{ |w| w.focus? }) and destructible?
          destroy
          true end } end

    def destroy
      Gtk::Lock.synchronize{
        @@ringlock.synchronize{
          if not(frozen?) and parent
            parent.remove(self)
            @@postboxes.delete(self)
            self.freeze end } } end

    def reply?
      ! @watch.is_a?(Post) end

    def retweet?
      @options[:retweet] end

    def regist
      @@ringlock.synchronize{
        @@postboxes << self } end

    def add_footer?
      if retweet?
        not UserConfig[:footer_exclude_retweet]
      elsif reply?
        not UserConfig[:footer_exclude_reply]
      else
        true end end

    def remain_charcount
      footer = if add_footer? then UserConfig[:footer].strsize else 0 end
      140 - @post.buffer.text.strsize - footer end

    def focus_out_event(widget, event=nil)
      Delayer.new(Delayer::NORMAL, @options){ |options|
        if(not(options.has_key?(:postboxstorage)) and post_is_empty?)
          destroy_if_necessary(send, tool) end }
      false end


    # Initialize Methods

    def generate_box
      @post, w_remain = generate_post
      @send = generate_send
      @tool = generate_tool
      Gtk::HBox.new(false, 0).closeup(@tool).pack_start(@post).closeup(w_remain).closeup(@send)
    end

    def generate_post
      w_remain = Gtk::Label.new('---')
      Delayer.new{ w_remain.set_text(remain_charcount.to_s) }
      post = Gtk::TextView.new
      post_set_default_text(post)
      post.wrap_mode = Gtk::TextTag::WRAP_CHAR
      post.border_width = 2
      post.signal_connect('key_press_event'){ |widget, event|
          if(widget.editable? and
             keyname([event.keyval ,event.state]) == keyname(UserConfig[:mumble_post_key]))
            post_it
            true end }
      post.signal_connect('key_release_event'){ |textview, event|
        w_remain.set_text(remain_charcount.to_s)
        send.sensitive = postable?
        tool.sensitive = destructible? if tool
        false }
      post.signal_connect_after('focus_out_event', &method(:focus_out_event))
      return post, w_remain end

    def generate_send
      send = Gtk::Button.new('!')
      send.sensitive = postable?
      send.signal_connect('clicked'){|button|
        post_it
        false }
      send end

    def generate_tool
      tool = Gtk::Button.new('-')
      tool.signal_connect_after('focus_out_event', &method(:focus_out_event))
      tool.signal_connect('event'){
        tool.sensitive = destructible?
        false }
      tool.signal_connect('button_release_event'){
        if posting?
          @post_thread.kill
          end_post
        else
          destroy if destructible? end
        false }
      tool end

    def post_set_default_text(post)
      if @options[:delegated_by]
        post.buffer.text = @options[:delegated_by].post.buffer.text
        @options[:delegated_by].post.buffer.text = ''
      elsif retweet?
        post.buffer.text = " RT @" + @watch.idname + ": " + @watch[:message]
        post.buffer.place_cursor(post.buffer.start_iter)
      elsif reply?
        post.buffer.text = '@' + @watch.idname + ' ' + post.buffer.text end
      post.accepts_tab = false end

  end
end
