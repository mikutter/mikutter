# -*- coding: utf-8 -*-
miquire :mui, 'extension'
miquire :mui, 'webicon'
miquire :mui, 'icon_over_button'
miquire :mui, 'skin'
miquire :mui, 'contextmenu'
miquire :mui, 'intelligent_textview'
miquire :core, 'message'
miquire :core, 'userconfig'
miquire :lib, 'weakstorage'

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

    DEFAULT_HEIGHT = 64

    attr_accessor :replies
    attr_reader :message
    alias to_message message

    @@contextmenu = Gtk::ContextMenu.new
    @@mumbles = Hash.new{ |h, k| h[k] = [] }
    @@active_mumbles = []

    @@contextmenu.registmenu("コピー", lambda{ |m,w|
                               w.is_a?(Gtk::TextView) and
                               w.buffer.selection_bounds[2] }){ |this, w|
      w.copy_clipboard }
    @@contextmenu.registmenu('本文をコピー', lambda{ |m,w|
                               Gtk::Mumble.active_mumbles.size == 1 and
                               w.is_a?(Gtk::TextView) and
                               not w.buffer.selection_bounds[2] }){ |this, w|
      w.select_all(true)
      w.copy_clipboard
      w.select_all(false) }
    @@contextmenu.registmenu("返信", lambda{ |m,w| m.message.repliable? }){ |this, w|
      this.gen_postbox(this.message, :subreplies => Gtk::Mumble.active_mumbles) }
    @@contextmenu.registmenu("全員に返信", lambda{ |m,w| m.message.repliable? }){ |this, w|
      this.gen_postbox(this.message,
                       :subreplies => this.message.ancestors,
                       :exclude_myself => true) }
    @@contextmenu.registmenu("引用", lambda{ |m,w|
                               Gtk::Mumble.active_mumbles.size == 1 and
                               m.message.repliable? }){ |this, w|
      this.gen_postbox(this.message, :retweet => true) }
    @@contextmenu.registmenu("公式リツイート", lambda{ |m,w|
                               m.message.repliable? and not m.message.from_me? }){ |this, w|
      Gtk::Mumble.active_mumbles.map{ |m| m.to_message }.uniq.select{ |m| not m.from_me? }.each{ |x| x.retweet } }
    @@contextmenu.registline
    delete_condition = lambda{ |m,w| Gtk::Mumble.active_mumbles.all?{ |e| e.message.from_me? } }
    @@contextmenu.registmenu('削除', delete_condition){ |this, w|
      Gtk::Mumble.active_mumbles.each { |e|
        e.message.destroy if Gtk::Dialog.confirm("本当にこのつぶやきを削除しますか？\n\n#{e.message.to_show}") } }
    @@contextmenu.registline(&delete_condition)

    def self.contextmenu
      @@contextmenu end

    def self.addlinkrule(reg, leftclick, rightclick=nil)
      Gtk::IntelligentTextview.addlinkrule(reg, leftclick, rightclick) end

    def self.addwidgetrule(reg, proc)
      Gtk::IntelligentTextview.addwidgetrule(reg, proc) end

    def self.active_mumbles
      @@active_mumbles end

    def self.inactive
      inactive = @@active_mumbles
      @@active_mumbles = []
      inactive.each{ |x| x.inactivate } end

    def initialize(message)
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

    def [](key)
      @message[key] end

    def modified
      @message.modified end

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

    def gen_postbox(message=@message, options={})
      options = options.melt
      Lock.synchronize{
        if(message.from_me? and message.receive_message)
          gen_postbox(message.receive_message, options)
        else
          postbox = Gtk::PostBox.new(message, options)
          @replies.add(postbox).show_all
          get_ancestor(Gtk::Window).set_focus(postbox.post)
        end } end

    def menu_pop(widget)
      Lock.synchronize{
        @@contextmenu.popup(widget, self) }
    end

    def replied_by(message)
      if UserConfig[:show_replied_icon]
        if @icon_over_button
          show_replied_icon
        else
          Delayer.new{
            if defined?(@icon_over_button) and not @icon_over_button.destroyed?
              show_replied_icon end } end end end

    def favorited_by
      @favorited_by ||= message.favorited_by.to_a end

    def retweeted_by
      @retweeted_by ||= [] end # ||= message.retweeted_by.to_a end

    def favorite(user)
      unless(favorited_by.include?(user))
        fav_box.closeup(icon(user, 24).show_all)
        favorited_by << user
        rewind_fav_count!
      end
    end

    def unfavorite(user)
      idx = favorited_by.index(user)
      if idx
        favorited_by.delete_at(idx)
        fav_box.remove(fav_box.children[idx])
        rewind_fav_count! end end

    def retweeted(user)
      type_strict user => User
      Delayer.new{
        if(not retweeted_box.destroyed?)
          unless(retweeted_by.include?(user))
            retweeted_box.closeup(icon(user, 24).show_all)
            retweeted_by << user
            if retweeted_box.children.size != retweeted_by.size
              p retweeted_box.children.size
              p retweeted_by
              abort
            end
            rewind_retweeted_count! end end } end

    # このメッセージを選択状態にする。
    # _append_ がtrueなら、既に選択されているものをクリアせず、自分の選択状態を反転する。
    # 最終的にアクティブになったかどうかを返す
    def active(append = false)
      if append
        if active?
          inactive
          false
        else
          @@active_mumbles.unshift(self)
          activate
          true end
      else
        if not active?
          inactives = @@active_mumbles
          @@active_mumbles = [self]
          inactives.each{ |x| x.inactivate }
          activate end
        true end end

    # このメッセージが選択状態ならtrueを返す
    def active?
      @@active_mumbles.include?(self) end

    # 選択状態を解除する
    def inactive
      @@active_mumbles.delete(self)
      inactivate
      false end

    # 選択されたときに呼ばれるメソッド
    def activate
      modifybg
    end
    alias inactivate activate

    private

    def rewind_fav_count!
      Lock.synchronize do
        return if(fav_box.destroyed?)
        if(fav_box.children.size == 0)
          fav_label.hide_all.set_no_show_all(true)
        else
          fav_label.set_text("#{fav_box.children.size} Fav ").set_no_show_all(false).show_all
        end
      end
    end

    def rewind_retweeted_count!
      Lock.synchronize do
        return if(retweeted_box.destroyed?)
        if(retweeted_box.children.size == 0)
          retweeted_label.hide_all.set_no_show_all(true)
        else
          retweeted_label.set_text("#{retweeted_box.children.size} RT ").set_no_show_all(false).show_all
        end
      end
    end

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
      body = Gtk::IntelligentTextview.new(message.to_show, fonts)
      body.signal_connect('button_press_event', &event_button_canceling)
      body.get_background = event_style_bg
      body.signal_connect('button_release_event', &method(:button_release_event))
      return body
    end

    def icon(msg, x, y=x)
      user = msg.is_a?(User) ? msg : msg.user
      Gtk::WebIcon.new(april_fool(user[:profile_image_url]), x, y)
    end

    def gen_minimumble(msg)
      Lock.synchronize{
        w = Gtk::HBox.new(false, 8)
        Thread.new{
          notice msg
          msg.user[:profile_image_url]
          Delayer.new{
            if(not w.destroyed?)
              w.closeup(icon(msg, 24).top)
              w.add(@in_reply_to = gen_body(msg,
                                            'foreground' => :mumble_reply_color,
                                            'font' => :mumble_reply_font)).show_all end } }
        w }
    end

    def gen_header(msg)
      user = msg.user
      idname = Gtk::Label.new(user[:idname])
      created = Gtk::Label.new(msg[:created].strftime('%H:%M:%S'))
      idname.style = Gtk::Style.new.set_font_desc(Pango::FontDescription.new('Sans 10').set_weight(700))
      created.style = Gtk::Style.new.set_fg(Gtk::STATE_NORMAL, *[0x66,0x66,0x66].map{|n| n*255 })
      Gtk::HBox.new(false, 16).closeup(idname).closeup(Gtk::Label.new((user[:name] or '').tr("\n", ' '))).add(created.right)
    end

    def gen_iob(msg)
      if defined?(@icon_over_button) and @icon_over_button
        @icon_over_button
      else
        iw = IOB.new(self, msg, Gtk::WebIcon.get_icon_pixbuf(msg.user[:profile_image_url], 48){ |pb|
                       iw.background = pb })
        iw.reply.retweet if(msg.repliable?)
        iw.etc
        iw.favorite if msg.favoriable?
        iw.bg_color = Gdk::Color.new(*get_backgroundcolor)
        @icon_over_button = iw end end

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
      reply.signal_connect('clicked'){ gen_postbox(message); false }
      retweet.signal_connect('clicked'){ gen_postbox(message, :retweet => true); false }
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
        signal_connect('visibility-notify-event'){
          modifybg
          false }
        signal_connect('button_release_event'){ |widget, event|
          if (event.button == 3)
            active unless active?
            menu_pop(@body)
            true end }
        signal_connect('button_release_event', &method(:button_release_event))
      } end

    def button_release_event(widget, event)
      if(event.button == 1)
        active((event.state & Gdk::Window::CONTROL_MASK) != 0) end
      false end

    @last_bg = []
    def modifybg
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
      Lock.synchronize{
        children.each{ |w| remove(w); w.destroy }
        @in_reply_to = @fav_label = @fav_box = @replies = @icon_over_button = nil } end

    def append_contents
      msg = @message
      if msg
        Lock.synchronize{
          breakout!
          shell = Gtk::VBox.new(false, 0)
          container = Gtk::HBox.new(false, 0)
          @replies = Gtk::VBox.new(false, 0)
          shell.border_width = 4
          mumble = Gtk::VBox.new(false, 0).add(gen_header(msg)).add(gen_control(msg))
          mumble.add(gen_reply(msg))
          mumble.add(gen_retweeted)
          mumble.add(gen_favorite)
          mumble.add(@replies)
          add(shell.add(container.add(mumble))).set_height_request(-1).show_all } end end

    def gen_reply(msg)
      reply = Gtk::VBox.new(false, 0)
      Thread.new{
        parent = msg.receive_message(UserConfig[:retrieve_force_mumbleparent])
        if(parent.is_a?(Message) and parent[:message])
          Delayer.new{
            if(not reply.destroyed?)
              reply.add(gen_minimumble(parent).show_all) end } end }
      reply end

    def gen_retweeted
      result = Gtk::HBox.new(false, 4).closeup(retweeted_label).closeup(retweeted_box).right
      Thread.new{
        Delayer.new(Delayer::NORMAL, message.retweeted_by){ |users|
          if(not destroyed?)
            users.each{ |user|
              retweeted(user) }
            rewind_retweeted_count! end } }
      result
    end

    def gen_favorite
      result = Gtk::HBox.new(false, 4).closeup(fav_label).closeup(fav_box).right
      Thread.new{
        Delayer.new(Delayer::NORMAL, favorited_by){ |users|
          if(not destroyed?)
            users.each{ |user|
              fav_box.closeup(icon(user, 24).show_all) }
            rewind_fav_count! end } }
      result
    end

    def retweeted_label
      @retweeted_label ||= Gtk::Label.new('').set_no_show_all(true) end

    def retweeted_box
      @retweeted_box ||= Gtk::HBox.new(false, 4) end

    def fav_label
      @fav_label ||= Gtk::Label.new('').set_no_show_all(true) end

    def fav_box
      @fav_box ||= Gtk::HBox.new(false, 4) end

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

  end end

