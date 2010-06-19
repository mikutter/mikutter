# -*- coding: utf-8 -*-
miquire :mui, 'extension'
miquire :mui, 'webicon'
miquire :mui, 'icon_over_button'
miquire :mui, 'skin'
miquire :mui, 'contextmenu'
miquire :mui, 'intelligent_textview'
miquire :core, 'message'
miquire :core, 'userconfig'

require 'gtk2'
require 'time'
require 'uri'
require_if_exist 'Win32API'

module Gtk
  class Mumble < Gtk::EventBox

    DEFAULT_HEIGHT = 64

    @@contextmenu = Gtk::ContextMenu.new

    attr_accessor :replies
    attr_reader :message

    @@contextmenu.registmenu("コピー", lambda{ |m,w|
                 w.is_a?(Gtk::TextView) and w.buffer.selection_bounds[2] }){ |this, w|
      w.copy_clipboard }
    @@contextmenu.registmenu('本文をコピー', lambda{ |m,w|
                 w.is_a?(Gtk::TextView) and not w.buffer.selection_bounds[2] }){ |this, w|
      w.select_all(true)
      w.copy_clipboard
      w.select_all(false) }
    @@contextmenu.registmenu("返信", lambda{ |m,w| m.message.repliable? }){ |this, w|
      this.gen_postbox(this.replies, this.message) }
    @@contextmenu.registmenu("引用", lambda{ |m,w| m.message.repliable? }){ |this, w|
      this.gen_postbox(this.replies, this.message, :retweet => true) }
    @@contextmenu.registmenu("公式リツイート", lambda{ |m,w|
                               m.message.repliable? and not m.message.from_me? }){ |this, w|
      this.message.retweet }
    @@contextmenu.registline
    @@contextmenu.registmenu('削除', lambda{ |m,w| m.message.from_me? }){ |this, w|
      this.message.destroy if Gtk::Dialog.confirm("本当にこのつぶやきを削除しますか？\n\n#{this.message.to_show}") }
    @@contextmenu.registline{ |m, w| m.message.from_me? }

    def self.contextmenu
      @@contextmenu end

    def initialize(message)
      @message = assert_type(Message, message)
      super()
      gen_mumble
      border_width = 0
    end

    def [](key)
      @message[key]
    end

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
      if Time.now.strftime('%m%d') == '0401' then
        "http://toshia.dip.jp/img/api/#{Digest::MD5.hexdigest(url)[0,1].downcase}.png"
      else
        url
      end
    end

    def self.addlinkrule(reg, leftclick, rightclick=nil)
      Gtk::IntelligentTextview.addlinkrule(reg, leftclick, rightclick) end

    def self.openurl(url)
      if(defined? Win32API) then
        shellExecuteA = Win32API.new('shell32.dll','ShellExecuteA',%w(p p p p p i),'i')
        shellExecuteA.call(0, 'open', url, 0, 0, 1)
      else
        system("/etc/alternatives/x-www-browser #{url} &") || system("firefox #{url} &")
      end
    end

    private

    def get_backgroundcolor
      if(@message.from_me?) then
        UserConfig[:mumble_self_bg]
      elsif(@message.to_me?) then
        UserConfig[:mumble_reply_bg]
      else
        UserConfig[:mumble_basic_bg]
      end
    end

    def gen_body(message, fonts={})
      body = Gtk::IntelligentTextview.new(message.to_show, fonts)
      body.get_background = lambda{ style.bg(Gtk::STATE_NORMAL) }
#       body.signal_connect('button_release_event'){ |widget, event|
#        Gtk::Lock.synchronize{
#          menu_pop(widget) if (event.button == 3) }
#       false }
      return body
    end

    def icon(msg, x, y=x)
      Gtk::WebIcon.new(april_fool(msg.user[:profile_image_url]), x, y)
    end

    def gen_minimumble(msg)
      Lock.synchronize{
        w = Gtk::HBox.new(false, 8)
        Thread.new{
          msg.user[:profile_image_url]
          Delayer.new{
            w.closeup(icon(msg, 24).top)
            w.add(gen_body(msg,
                           'foreground' => :mumble_reply_color,
                           'font' => :mumble_reply_font)).show_all } }
        w }
    end

    def gen_header(msg)
      user = msg.user
      idname = Gtk::Label.new(user[:idname])
      created = Gtk::Label.new(msg[:created].strftime('%H:%M:%S'))
      idname.style = Gtk::Style.new.set_font_desc(Pango::FontDescription.new('Sans 10').set_weight(700))
      created.style = Gtk::Style.new.set_fg(Gtk::STATE_NORMAL, *[0x66,0x66,0x66].map{|n| n*255 })
      Gtk::HBox.new(false, 16).closeup(idname).closeup(Gtk::Label.new(user[:name])).add(created.right)
    end

    def gen_iob(msg)
      iw = IOB.new(self, msg, icon(msg, 48))
      iw.reply.retweet if(msg.repliable?)
      iw.etc
      iw.favorite if msg.favoriable?
      iw
    end

    def gen_control(msg)
      @body = gen_body(msg, 'font' => :mumble_basic_font, 'foreground' => :mumble_basic_color)
      control = Gtk::HBox.new(false, 8).closeup(gen_iob(msg).top)
      control.add(@body)
      control.closeup(cumbersome_buttons(msg)) if(UserConfig[:show_cumbersome_buttons])
      control
    end

    def cumbersome_buttons(message)
      reply = Gtk::Button.new.add(Gtk::WebIcon.new(MUI::Skin.get("reply.png"), 16, 16))
      retweet = Gtk::Button.new.add(Gtk::WebIcon.new(MUI::Skin.get("retweet.png"), 16, 16))
      reply.signal_connect('clicked'){ gen_postbox(@replies, message); false }
      retweet.signal_connect('clicked'){ gen_postbox(@replies, message, :retweet => true); false }
      Gtk::VBox.new(false, 0).closeup(Gtk::HBox.new(false, 4).closeup(reply).closeup(retweet))
    end

    def gen_mumble
      Lock.synchronize{
        set_size_request(1, DEFAULT_HEIGHT)
        last_set_config = nil
        signal_connect('expose_event'){
          if (relation_configure != last_set_config) then
            append_contents
            last_set_config = relation_configure
          end
          false }
        last_bg = []
        signal_connect('visibility-notify-event'){
          if(last_bg != get_backgroundcolor)
            last_bg = get_backgroundcolor
            style = Gtk::Style.new()
            style.set_bg(Gtk::STATE_NORMAL, *get_backgroundcolor)
            self.style = style end
          false }
        signal_connect('button_release_event'){ |widget, event|
          Gtk::Lock.synchronize{
            if (event.button == 3)
              menu_pop(@body)
              true end } } } end

    def append_contents
      msg = if @message[:retweet] then @message[:retweet] else @message end
      Lock.synchronize{
        children.each{ |w| remove(w) }
        shell = Gtk::VBox.new(false, 0)
        container = Gtk::HBox.new(false, 0)
        @replies = Gtk::VBox.new(false, 0)
        shell.border_width = 4
        mumble = Gtk::VBox.new(false, 0).add(gen_header(msg)).add(gen_control(msg))
        mumble.add(gen_reply(msg))
        mumble.add(gen_retweet(@message)) if @message[:retweet]
        mumble.add(@replies)
        add(shell.add(container.add(mumble))).set_height_request(-1).show_all }
    end

    def gen_reply(msg)
      reply = Gtk::VBox.new(false, 0)
      Thread.new(reply, msg){ |reply, msg|
        parent = msg.receive_message(UserConfig[:retrieve_force_mumbleparent])
        if(parent.is_a?(Message) and parent[:message]) then
          Delayer.new(Delayer::NORMAL, reply, parent){ |reply, parent|
            Lock.synchronize{ reply.add(gen_minimumble(parent).show_all) } }
        end }
      reply
    end

    def gen_retweet(msg)
      Gtk::HBox.new(false, 4).closeup(Gtk::Label.new('ReTweeted by ' + msg.user[:idname])).
        closeup(icon(msg, 24)).right
    end

    def relation_configure
      [UserConfig[:show_cumbersome_buttons], UserConfig[:retrieve_force_mumbleparent]]
    end

    public

    def gen_postbox(replies, message, options={})
      Lock.synchronize{
        postbox = Gtk::PostBox.new(message, options)
        replies.add(postbox).show_all
        get_ancestor(Gtk::Window).set_focus(postbox.post)
      }
    end

    def menu_pop(widget)
      Lock.synchronize{
        @@contextmenu.popup(widget, self) }
    end

    class IOB < Gtk::IconOverButton
      @@buttons = {
        :reply => Gtk::WebIcon.new(MUI::Skin::get("reply.png"), 24, 24),
        :retweet => Gtk::WebIcon.new(MUI::Skin::get("retweet.png"), 24, 24),
        :fav => {
          false => Gtk::WebIcon.new(MUI::Skin::get("fav.png"), 24, 24),
          true => Gtk::WebIcon.new(MUI::Skin::get("unfav.png"), 24, 24) },
        :etc => Gtk::WebIcon.new(MUI::Skin::get("etc.png"), 24, 24) }

      def initialize(mumble, msg, icon)
        @mumble = mumble
        @msg = msg
        super(icon)
        set_size_request(48, 48).set_grid_size(2, 2)
        sub_button{ @mumble.menu_pop(self) }
        set_buttonback(MUI::Skin.get("overbutton.png"),
                       MUI::Skin.get("overbutton_mouseover.png")) end

      def reply
        add(@@buttons[:reply]){ @mumble.gen_postbox(@mumble.replies, @msg) }
      end

      def retweet
        add(@@buttons[:retweet]){ @mumble.gen_postbox(@mumble.replies, @msg, :retweet => true) }
      end

      def etc
        add(@@buttons[:etc]){ @mumble.menu_pop(self) }
      end

      def favorite
        add(@@buttons[:fav][@msg.favorite?], :always_show => @msg.favorite?){ |this, options|
          @msg.favorite(!@msg.favorite?)
          options[:always_show] = @msg[:favorited] = !@msg.favorite?
          [@@buttons[:fav][@msg.favorite?], options] } end end end end
