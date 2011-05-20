# -*- coding:utf-8 -*-
=begin
= Gtk::PostBox
つぶやき入力ボックス。
=end

require 'gtk2'
require 'thread'
miquire :mui, 'miracle_painter'

module Gtk
  class PostBox < Gtk::EventBox

    attr_accessor :post, :send, :tool, :return_to_top

    @@ringlock = Mutex.new
    @@postboxes = []

    # 既存のGtk::PostBoxのインスタンスを返す
    def self.list
      return @@postboxes
    end

    def initialize(watch, options = {})
      mainthread_only
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
      regist end

    def posting?
      @posting end

    def active
      get_ancestor(Gtk::Window).set_focus(@post) if(get_ancestor(Gtk::Window)) end

    def on_delete
      if(block_given?)
        @on_delete = Proc.new
      elsif defined? @on_delete
        @on_delete.call end end

    def post_it
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
          notice [event, msg].inspect
          case event
          when :start
            Delayer.new{ start_post }
          when :fail
            Delayer.new{ end_post }
          when :success
            Delayer.new{ destroy } end } end end

    private

    def postable?
      not(@post.buffer.text.empty?) and (/[^\s]/ === @post.buffer.text) end

    def start_post
      if not(frozen? or destroyed?)
        @posting = true
        post.editable = false
        [post, send].compact.each{|widget| widget.sensitive = false }
        tool.sensitive = true end end

    def end_post
      if not(frozen? or destroyed?)
        @posting = false
        post.editable = true
        [post, send].compact.each{|widget| widget.sensitive = true } end end

    def delegate
      Gtk::Lock.synchronize{
        if(@options[:postboxstorage] and @options[:delegate_other])
          options = @options.clone
          options[:delegate_other] = false
          options[:delegated_by] = self
          @options[:postboxstorage].pack_start(Gtk::PostBox.new(@watch, options)).show_all
          true end } end

    def service
      if UserConfig[:legacy_retweet_act_as_reply]
        @watch
      else
        (retweet? ? @watch.service : @watch) end end

    def post_is_empty?
      frozen? and @post.buffer.text == "" or
        (defined?(@watch[:user]) and
         @post.buffer.text == "@#{@watch[:user][:idname]} ") end

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
        if(not(frozen?) and not([@post, *related_widgets].compact.any?{ |w| w.focus? }) and
           destructible?)
          destroy
          true end } end

    def destroy
      @@ringlock.synchronize{
        if not(frozen?) and parent
          parent.remove(self)
          @@postboxes.delete(self)
          super
          on_delete
          self.freeze end } end

    def reply?
      @watch.is_a?(Retriever::Model) end

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
        if(not(frozen?) and not(options.has_key?(:postboxstorage)) and post_is_empty?)
          destroy_if_necessary(send, tool) end }
      false end

    # Initialize Methods

    def generate_box
      @post, w_remain = generate_post
      @send = generate_send
      @tool = generate_tool
      result = Gtk::HBox.new(false, 0).closeup(@tool).pack_start(@post).closeup(w_remain).closeup(@send)
      if(@watch.is_a?(Message))
        mp = Gdk::MiraclePainter.new(@watch, 300)
        da = Gtk::DrawingArea.new
        da.signal_connect(:expose_event){
          mp.width = da.window.geometry[2]
          da.height_request = mp.height
          gc = Gdk::GC.new(da.window)
          da.window.draw_drawable(gc, mp.pixmap, 0, 0, 0, 0, mp.width, mp.height)
          false
        }
        Gtk::VBox.new.closeup(da).add(result)
      else
        result end end

    def generate_post
      w_remain = Gtk::Label.new('---')
      Delayer.new{ w_remain.set_text(remain_charcount.to_s) }
      post = Gtk::TextView.new
      post_set_default_text(post)
      post.wrap_mode = Gtk::TextTag::WRAP_CHAR
      post.border_width = 2
      post.signal_connect('key_press_event'){ |widget, event|
        Addon::Command.call_keypress_event(Gtk::keyname([event.keyval ,event.state]), :postbox => self)
          # if(widget.editable? and
          #    Gtk::keyname([event.keyval ,event.state]) == UserConfig[:mumble_post_key])
          #   post_it
          #   true end
      }
      post.signal_connect('key_release_event'){ |textview, event|
        w_remain.set_text(remain_charcount.to_s)
        send.sensitive = postable?
        tool.sensitive = destructible? if tool
        false }
      post.signal_connect_after('focus_out_event', &method(:focus_out_event))
      post.signal_connect_after('focus_in_event'){
        Delayer.new{ Gtk::Mumble.inactive } if defined? Gtk::Mumble
        # mumble = get_ancestor(Gtk::Mumble.superclass)
        # if mumble.is_a? Gtk::Mumble
        #   mumble.active
        # else
        #   Gtk::Mumble.inactive end
      }
      return post, w_remain end

    def generate_send
      send = Gtk::Button.new.add(Gtk::WebIcon.new(MUI::Skin.get('post.png'), 16, 16))
      send.sensitive = postable?
      send.signal_connect('clicked'){|button|
        post_it
        false }
      send end

    def generate_tool
      tool = Gtk::Button.new.add(Gtk::WebIcon.new(MUI::Skin.get('close.png'), 16, 16))
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
        post.buffer.text = " RT @" + @watch.idname + ": " + @watch.to_show
        post.buffer.place_cursor(post.buffer.start_iter)
      elsif reply?
        post.buffer.text = reply_users + ' ' + post.buffer.text end
      post.accepts_tab = false end

    def reply_users
      replies = [@watch.idname]
      if(@options[:subreplies].is_a? Enumerable)
        replies += @options[:subreplies].map{ |m| m.to_message.idname } end
      if @options[:exclude_myself]
        replies = replies.select{|x| x != @watch.service.idname }
      end
      replies.uniq.map{ |x| "@#{x}" }.join(' ')
    end

  end
end
