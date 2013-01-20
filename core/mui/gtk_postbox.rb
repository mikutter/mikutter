# -*- coding:utf-8 -*-
=begin
= Gtk::PostBox
つぶやき入力ボックス。
=end

require 'gtk2'
require 'thread'
miquire :mui, 'miracle_painter'
miquire :mui, 'intelligent_textview'

module Gtk
  class PostBox < Gtk::EventBox

    attr_accessor :return_to_top

    @@ringlock = Mutex.new
    @@postboxes = []

    # 既存のGtk::PostBoxのインスタンスを返す
    def self.list
      return @@postboxes
    end

    def initialize(watch, options = {})
      mainthread_only
      @posting = nil
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
      set_border_width(2)
      regist end

    def generate_box
      @replies = []
      result = Gtk::HBox.new(false, 0).closeup(widget_tool).pack_start(widget_post).closeup(widget_remain).closeup(widget_send)
      if(reply?)
        w_replies = Gtk::VBox.new.add(result)
        in_reply_to_all.each{ |message|
          w_reply = Gtk::HBox.new
          itv = Gtk::IntelligentTextview.new(message.to_show, 'font' => :mumble_basic_font)
          itv.get_background = lambda{ get_backgroundstyle(message) }
          itv.bg_modifier
          ev = Gtk::EventBox.new
          ev.style = get_backgroundstyle(message)
          w_replies.closeup(ev.add(w_reply.closeup(Gtk::WebIcon.new(message[:user][:profile_image_url], 32, 32).top).add(itv)))
          @replies << itv
        }
        w_replies
      else
        result end end

    def widget_post
      return @post if defined?(@post)
      @post = gen_widget_post
      post_set_default_text(@post)
      @post.wrap_mode = Gtk::TextTag::WRAP_CHAR
      @post.border_width = 2
      @post.ssc('key_release_event'){ |textview, event|
        refresh_buttons(false)
        false }
      @post.ssc('paste-clipboard'){ |this|
        Delayer.new{ refresh_buttons(false) }
        false }
      @post.signal_connect_after('focus_out_event', &method(:focus_out_event))
      @post end
    alias post widget_post

    def widget_remain
      return @remain if defined?(@remain)
      @remain = Gtk::Label.new('---')
      Delayer.new{
        if not @remain.destroyed?
          @remain.set_text(remain_charcount.to_s) end }
      widget_post.ssc('key_release_event'){ |textview, event|
        @remain.set_text(remain_charcount.to_s) }
      widget_post.ssc('paste-clipboard'){ |this|
        @remain.set_text(remain_charcount.to_s) }
      @remain end

    def widget_send
      return @send if defined?(@send)
      @send = Gtk::Button.new.add(Gtk::WebIcon.new(Skin.get('post.png'), 16, 16))
      @send.sensitive = postable?
      @send.signal_connect('clicked'){|button|
        post_it
        false }
      @send end

    def widget_tool
      return @tool if defined?(@tool)
      @tool = Gtk::Button.new.add(Gtk::WebIcon.new(Skin.get('close.png'), 16, 16))
      @tool.signal_connect_after('focus_out_event', &method(:focus_out_event))
      @tool.ssc('event'){
        @tool.sensitive = destructible? || posting?
        false }
      @tool.ssc('clicked'){
        if posting?
          @posting.cancel
          @tool.sensitive = destructible? || posting?
          cancel_post
        else
          destroy if destructible? end
        false }
      @tool end

    # 各ボタンのクリック可否状態を更新する
    def refresh_buttons(refresh_brothers = true)
      if refresh_brothers and @options.has_key?(:postboxstorage)
        @options[:postboxstorage].children.each{ |brother|
          brother.refresh_buttons(false) }
      else
        widget_send.sensitive = postable?
        widget_tool.sensitive = destructible? || posting? end end

    # 現在メッセージの投稿中なら真を返す
    def posting?
      !!@posting end

    # このPostBoxにフォーカスを合わせる
    def active
      get_ancestor(Gtk::Window).set_focus(widget_post) if(get_ancestor(Gtk::Window)) end

    # 入力されている投稿する。投稿に成功したら、self.destroyを呼んで自分自身を削除する
    def post_it
      if postable?
        return unless before_post
        text = widget_post.buffer.text
        text += UserConfig[:footer] if add_footer?
        @posting = service.post(:message => text){ |event, msg|
          notice [event, msg].inspect
          case event
          when :start
            Delayer.new{ start_post }
          when :fail
            Delayer.new{ end_post }
          when :success
            Delayer.new{ destroy } end } end end

    def destroy
      @@ringlock.synchronize{
        if not(destroyed?) and not(frozen?) and parent
          parent.remove(self)
          @@postboxes.delete(self)
          super
          on_delete
          self.freeze end } end

    private

    def gen_widget_post
      Gtk::TextView.new end

    def postable?
      not(widget_post.buffer.text.empty?) and (/[^\s]/ === widget_post.buffer.text) end

    # 新しいPostBoxを作り、そちらにフォーカスを回す
    def before_post
      if(@options[:postboxstorage])
        return false if delegate
        if not @options[:delegated_by]
          postbox = Gtk::PostBox.new(@watch, @options)
          @options[:postboxstorage].
            pack_start(postbox).
            show_all.
            get_ancestor(Gtk::Window).
            set_focus(postbox.widget_post) end end
      if @options[:before_post_hook]
        @options[:before_post_hook].call(self) end
      Plugin.call(:before_postbox_post, widget_post.buffer.text)
      true end

    def start_post
      if not(frozen? or destroyed?)
        # @posting = Thread.current
        widget_post.editable = false
        [widget_post, widget_send].compact.each{|widget| widget.sensitive = false }
        widget_tool.sensitive = true
      end end

    def end_post
      if not(frozen? or destroyed?)
        @posting = nil
        widget_post.editable = true
        [widget_post, widget_send].compact.each{|widget| widget.sensitive = true } end end

    # ユーザによって投稿が中止された場合に呼ばれる
    def cancel_post
      if not(frozen? or destroyed?)
        if @options[:delegated_by]
          @options[:delegated_by].widget_post.buffer.text = widget_post.buffer.text
          destroy
        else
          end_post end end end

    def delegate
      if(@options[:postboxstorage] and @options[:delegate_other])
        options = @options.clone
        options[:delegate_other] = false
        options[:delegated_by] = self
        @options[:postboxstorage].pack_start(Gtk::PostBox.new(@watch, options)).show_all
        true end end

    def service
      if UserConfig[:legacy_retweet_act_as_reply]
        @watch
      else
        (retweet? ? @watch.service : @watch) end end

    def post_is_empty?
      widget_post.buffer.text.empty? or
        (defined?(@watch[:user]) ? widget_post.buffer.text == "@#{@watch[:user][:idname]} " : false) end

    def brothers
      if(@options[:postboxstorage])
        @options[:postboxstorage].children.find_all{|c| c.sensitive? }
      else
        [] end end

    def lonely?
      brothers.size <= 1 end

    # フォーカスが外れたことによって削除して良いなら真を返す。
    def destructible?
      if(@options.has_key?(:postboxstorage))
        return false if lonely? or (brothers - [self]).any?{ |w| w.posting? }
        post_is_empty?
      else
        true end end

    # _related_widgets_ のうちどれもアクティブではなく、フォーカスが外れたら削除される設定の場合、このウィジェットを削除する
    def destroy_if_necessary(*related_widgets)
      if(not(frozen?) and not([widget_post, *related_widgets].compact.any?{ |w| w.focus? }) and destructible?)
        destroy
        true end end

    def on_delete
      if(block_given?)
        @on_delete = Proc.new
      elsif defined? @on_delete
        @on_delete.call end end

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
      if not widget_post.destroyed?
        footer = if add_footer? then UserConfig[:footer].size else 0 end
        140 - widget_post.buffer.text.size - footer end end

    def focus_out_event(widget, event=nil)
      Delayer.new(Delayer::NORMAL, @options){ |options|
        if(not(frozen?) and not(options.has_key?(:postboxstorage)) and post_is_empty?)
          destroy_if_necessary(widget_send, widget_tool, *@replies) end }
      false end

    # Initialize Methods

    def get_backgroundcolor(message)
      if(message.from_me?)
        UserConfig[:mumble_self_bg]
      elsif(message.to_me?)
        UserConfig[:mumble_reply_bg]
      else
        UserConfig[:mumble_basic_bg] end end

    def get_backgroundstyle(message)
      style = Gtk::Style.new()
      color = get_backgroundcolor(message)
      [Gtk::STATE_ACTIVE, Gtk::STATE_NORMAL, Gtk::STATE_SELECTED, Gtk::STATE_PRELIGHT, Gtk::STATE_INSENSITIVE].each{ |state|
        style.set_bg(state, *color) }
      style end

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

    # 全てのリプライ元を返す
    def in_reply_to_all
      result = Set.new
      if reply?
        result << @watch
        if @options[:subreplies].is_a? Enumerable
          result += @options[:subreplies] end end
      result end

  end
end
