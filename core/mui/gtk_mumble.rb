# -*- coding: utf-8 -*-
miquire :mui, 'extension'
miquire :mui, 'webicon'
miquire :mui, 'icon_over_button'
miquire :mui, 'skin'
miquire :mui, 'contextmenu'
miquire :mui, 'intelligent_textview'
miquire :core, 'message'
miquire :core, 'userconfig'
miquire :core, 'serialthread'
miquire :core, 'delayer'
miquire :lib, 'weakstorage'
miquire :mui, 'mumble_vote'
miquire :mui, 'mumble_select'

require 'gtk2'
require 'time'
require 'uri'
require_if_exist 'Win32API'

module Gtk
=begin rdoc
= Gtk::Mumble つぶやきを表示するためのクラス
つぶやきのアイコンや本文などの表示と、ボタンクリックの制御を担当。
普通 Gtk::TimeLine から使用されるため、このクラスを直接叩くことはない
=end
  class Mumble < Gtk::EventBox

    include Gtk::MumbleVote
    include Gtk::MumbleSelect

    # ロード前のウィジェットの高さ
    DEFAULT_HEIGHT = 64 + 24

    attr_accessor :replies
    attr_reader :message
    alias to_message message
    define_voter :favorited, 'Fav'
    define_voter :retweeted, 'RT'
    @@mumbles = Hash.new{ |h, k| h[k] = [] }

    def self.addlinkrule(reg, leftclick, rightclick=nil)
      Gtk::IntelligentTextview.addlinkrule(reg, leftclick, rightclick) end

    def self.addwidgetrule(reg, proc)
      Gtk::IntelligentTextview.addwidgetrule(reg, proc) end

    def initialize(message)
      mainthread_only
      type_strict message => Message
      @message = message
      super()
      gen_mumble
      border_width = 0
      @@mumbles[message[:id]] << self
      signal_connect('destroy'){
        raise 'mumble not found in mumbles chain' unless @@mumbles[@message[:id]].delete(self)
        @@mumbles.delete(@message[:id]) if(@@mumbles[@message[:id]].empty?)
        false } end

    # Message#[]
    def [](key)
      @message[key] end

    # Message#modified
    def modified
      @message.modified end

    # 前後関係を返す。
    def <=>(other)
      if defined?(other.to_a)
        to_a <=> other.to_a
      elsif other.is_a? Integer
        self[:id].to_i <=> other
      elsif other.is_a? Time
        self[:created] <=> other end end

    def to_a
      [self[:created], self[:id].to_i]
    end

    def april_fool(url)
      now = Time.now
      if now.strftime('%m%d') == '0401'
        "http://toshia.dip.jp/img/api/#{Digest::MD5.hexdigest(url)[0,2].upcase}.png"
      elsif now.strftime('%m') == '03' and rand(100) < now.strftime('%d').to_i
        SerialThread.lator{
          notice "prefetch cache image #{url}"
          Gtk::WebIcon.local_path("http://toshia.dip.jp/img/api/#{Digest::MD5.hexdigest(url)[0,2].upcase}.png") }
        url
      else
        url
      end
    end

    def gen_postbox(message=@message, options={})
      mainthread_only
      options = options.melt
      if(message.from_me? and message.receive_message)
        gen_postbox(message.receive_message, options)
      else
        postbox = Gtk::PostBox.new(message, options)
        @replies.add(postbox).show_all
        get_ancestor(Gtk::Window).set_focus(postbox.post)
      end end

    def menu_pop(widget)
      mainthread_only
      menu = []
      Plugin.filtering(:contextmenu, []).first.each{ |x|
        cur = x.first
        cur = cur.call(nil, nil) if cur.respond_to?(:call)
        index = where_should_insert_it(cur, menu, UserConfig[:mumble_contextmenu_order] || [])
        menu[index] = x
      }
      Gtk::ContextMenu.new(*menu).popup(widget, self)
    end

    def replied_by(message)
      mainthread_only
      if UserConfig[:show_replied_icon]
        if @icon_over_button
          show_replied_icon
        else
          Delayer.new{
            if defined?(@icon_over_button) and not @icon_over_button.destroyed?
              show_replied_icon end } end end end

    # 選択されたときに呼ばれるメソッド
    def activate
      super
      unless ancestor?(get_ancestor(Gtk::Window).focus)
        get_ancestor(Gtk::Window).set_focus(@body) if @body
      end
      modifybg
    end

    # 選択解除されたときに呼ばれるメソッド
    def inactivate
      super
      modifybg
    end

    private

    def get_backgroundcolor
      if(active?)
        UserConfig[:mumble_selected_bg]
      elsif(@message.from_me?)
        UserConfig[:mumble_self_bg]
      elsif(@message.to_me?)
        UserConfig[:mumble_reply_bg]
      else
        UserConfig[:mumble_basic_bg]
      end
    end

    def event_button_canceling
      lambda{ |widget, event| event.button == 3 } end

    def event_style_bg
      lambda{ style.bg(Gtk::STATE_NORMAL) } end

    def gen_body(message, fonts={})
      mainthread_only
      body = Gtk::IntelligentTextview.new(message.to_show, fonts)
      body.signal_connect('button_press_event', &event_button_canceling)
      body.get_background = event_style_bg
      body.signal_connect('button_release_event', &method(:button_release_event))
      body
    end

    def icon(msg, x, y=x)
      mainthread_only
      user = msg.is_a?(User) ? msg : msg.user
      Gtk::WebIcon.new(april_fool(user[:profile_image_url]), x, y)
    end

    def gen_minimumble(msg)
      mainthread_only
      w = Gtk::HBox.new(false, 8)
      Thread.new{
        msg.user[:profile_image_url]
        Delayer.new{
          if(not w.destroyed?)
            w.closeup(icon(msg, 24).top)
            w.add(@in_reply_to = gen_body(msg,
                                          'foreground' => :mumble_reply_color,
                                          'font' => :mumble_reply_font)).show_all end } }
      w
    end

    def gen_header(msg)
      mainthread_only
      user = msg.user
      idname = Gtk::Label.new(user[:idname])
      created = Gtk::Label.new(msg[:created].strftime('%H:%M:%S'))
      idname.style = Gtk::Style.new.set_font_desc(Pango::FontDescription.new('Sans 10').set_weight(700))
      created.style = Gtk::Style.new.set_fg(Gtk::STATE_NORMAL, *[0x66,0x66,0x66].map{|n| n*255 })
      Gtk::HBox.new(false, 16).closeup(idname).closeup(Gtk::Label.new((user[:name] or '').tr("\n", ' '))).add(created.right)
    end

    def gen_iob(msg)
      mainthread_only
      if defined?(@icon_over_button) and @icon_over_button
        @icon_over_button
      else
        iw = IOB.new(self, msg, Gtk::WebIcon.get_icon_pixbuf(april_fool(msg.user[:profile_image_url]), 48){ |pb|
                       iw.background = pb })
        iw.reply.retweet if(msg.repliable?)
        iw.etc
        iw.favorite if msg.favoriable?
        iw.bg_color = Gdk::Color.new(*get_backgroundcolor)
        @icon_over_button = iw end end

    def gen_control(msg)
      mainthread_only
      @body = gen_body(msg, 'font' => :mumble_basic_font, 'foreground' => :mumble_basic_color)
      control = Gtk::HBox.new(false, 8).closeup(gen_iob(msg).top)
      control.add(@body)
      control.closeup(cumbersome_buttons(msg)) if(UserConfig[:show_cumbersome_buttons])
      control
    end

    def cumbersome_buttons(message)
      mainthread_only
      reply = Gtk::Button.new.add(Gtk::WebIcon.new(MUI::Skin.get("reply.png"), 16, 16))
      retweet = Gtk::Button.new.add(Gtk::WebIcon.new(MUI::Skin.get("retweet.png"), 16, 16))
      reply.signal_connect('clicked'){ gen_postbox(message); false }
      retweet.signal_connect('clicked'){ gen_postbox(message, :retweet => true); false }
      Gtk::VBox.new(false, 0).closeup(Gtk::HBox.new(false, 4).closeup(reply).closeup(retweet))
    end

    def gen_mumble
      mainthread_only
      set_size_request(1, DEFAULT_HEIGHT)
      last_set_config = nil
      signal_connect('expose_event'){
        if (relation_configure != last_set_config) then
          append_contents
          last_set_config = relation_configure
        end
        false }
      signal_connect('visibility-notify-event'){
        modifybg
        false }
      signal_connect('button_release_event'){ |widget, event|
        if (event.button == 3)
          active unless active?
          menu_pop(@body)
          true end }
      signal_connect('button_release_event', &method(:button_release_event))
    end

    def button_release_event(widget, event)
      if(event.button == 1)
        active((event.state & Gdk::Window::CONTROL_MASK) != 0) end
      false end

    @last_bg = []
    def modifybg
      mainthread_only
      if(@last_bg != get_backgroundcolor and not destroyed?)
        @last_bg = get_backgroundcolor
        style = Gtk::Style.new()
        [Gtk::STATE_ACTIVE, Gtk::STATE_NORMAL, Gtk::STATE_SELECTED, Gtk::STATE_PRELIGHT, Gtk::STATE_INSENSITIVE].each{ |state|
          style.set_bg(state, *get_backgroundcolor)
        }
        self.style = style
        @body.bg_modifier if @body
        @in_reply_to.bg_modifier if @in_reply_to end end

    def breakout!
      mainthread_only
      children.each{ |w| remove(w); w.destroy }
      @in_reply_to = @fav_label = @fav_box = @replies = @icon_over_button = nil end

    def append_contents
      mainthread_only
      if @message
        breakout!
        shell = Gtk::VBox.new(false, 0)
        container = Gtk::HBox.new(false, 0)
        @replies = Gtk::VBox.new(false, 0)
        shell.border_width = 4
        mumble = Gtk::VBox.new(false, 0)
        [gen_header(@message), gen_control(@message), gen_reply, gen_retweeted, gen_favorited, @replies].each{ |w|
          unless(mumble.destroyed?)
            mumble.add(w) end }
        add(shell.add(container.add(mumble))).set_height_request(-1).show_all
        Delayer.new{ gen_additional_widgets } end end

    def gen_reply
      @gen_reply ||= Gtk::VBox.new(false, 0) end

    # リプライ、リツイート、ふぁぼられのウィジェットの初期値を設定する。
    # ただし、投稿されてから3秒以内のつぶやきは基本的にリツイート、ふぁぼられはないと
    # 思われるので（3秒以内にする迷惑な奴おるけどな）、リプライ元しか初期化しようとしない
    def gen_additional_widgets
      if message[:created] <= (Time.now - 3)
        SerialThread.new{
          reply_packer if message.has_receive_message?
          retweeted_packer
          favorited_packer }
      elsif message.has_receive_message?
        SerialThread.new{ reply_packer } end end

    def reply_packer
      parent = message.receive_message(UserConfig[:retrieve_force_mumbleparent])
      if(parent.is_a?(Message) and parent[:message])
        Delayer.new{
          if(not gen_reply.destroyed?)
            gen_reply.add(gen_minimumble(parent).show_all) end } end end

    def relation_configure
      [UserConfig[:show_cumbersome_buttons], UserConfig[:retrieve_force_mumbleparent]]
    end

    def show_replied_icon
      @icon_over_button.options[0][:always_show] = true if defined?(@icon_over_button.options) end

    class IOB < Gtk::IconOverButton
      @@buttons = {
        :reply => Gdk::Pixbuf.new(MUI::Skin::get("reply.png"), 24, 24),
        :retweet => Gdk::Pixbuf.new(MUI::Skin::get("retweet.png"), 24, 24),
        :fav => {
          false => Gdk::Pixbuf.new(MUI::Skin::get("fav.png"), 24, 24),
          true => Gdk::Pixbuf.new(MUI::Skin::get("unfav.png"), 24, 24) },
        :etc => Gdk::Pixbuf.new(MUI::Skin::get("etc.png"), 24, 24) }

      def initialize(mumble, msg, icon)
        mainthread_only
        @mumble = mumble
        @msg = msg
        type_strict mumble => Gtk::Mumble, msg => Message
        super(icon)
        set_size_request(48, 48).set_grid_size(2, 2)
        sub_button{ @mumble.menu_pop(self) }
        set_buttonback(MUI::Skin.get("overbutton.png"),
                       MUI::Skin.get("overbutton_mouseover.png")) end

      def reply
        add(@@buttons[:reply], :always_show => lambda{
              UserConfig[:show_replied_icon] && @mumble.message.children.any?{ |m| m.from_me? }
            }){ @mumble.gen_postbox(@msg) } end

      def retweet
        add(@@buttons[:retweet]){ @mumble.gen_postbox(@msg, :retweet => true) }
      end

      def etc
        add(@@buttons[:etc]){ @mumble.menu_pop(self) }
      end

      def favorite
        add(lambda{ @@buttons[:fav][@msg.favorite?] }, :always_show => lambda{ @msg.favorite? }){ |this, options|
          @msg.favorite(!@msg.favorite?)
          options[:always_show] = @msg[:favorited] = !@msg.favorite?
          [@@buttons[:fav][@msg.favorite?], options] } end end

    if defined? Plugin
      Plugin.create(:gtk_mumble).add_event(:posted){ |service, messages|
        messages.each{ |message|
          parent = message.receive_message
          if parent.is_a?(Message) and @@mumbles.include?(parent[:id])
            @@mumbles[parent[:id]].each{ |mumble|
              mumble.replied_by(message)
            }
          end
        }
      }
    end

  end end

