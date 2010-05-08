miquire :mui, 'extension'
miquire :mui, 'webicon'
miquire :mui, 'icon_over_button'
miquire :mui, 'skin'
miquire :core, 'message'

require 'gtk2'
require 'time'
require 'uri'
require_if_exist 'Win32API'

module Gtk
  class Mumble < Gtk::EventBox

    DEFAULT_HEIGHT = 64

    @@linkrule = [[ URI.regexp(['http','https']), lambda{ |u| Mumble.openurl u} ]]

    attr_accessor :replies

    def initialize(message)
      @message = assert_type(Message, message)
      super()
      gen_mumble
      border_width = 0
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

    def self.addlinkrule(reg, proc)
      @@linkrule = @@linkrule.push([reg, proc]) end

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
        [255,255,222]
      elsif(@message.to_me?) then
        [255,222,222]
      else
        [255,255,255]
      end
    end

    def set_cursor(textview, cursor)
      textview.get_window(Gtk::TextView::WINDOW_TEXT).set_cursor(Gdk::Cursor.new(cursor))
    end

    def apply_links(buffer)
      @@linkrule.each{ |pair|
        reg, proc = pair
        buffer.text.each_matches(reg){ |match, index|
          index = buffer.text[0, index].split(//u).size
          tag = buffer.create_tag(match, 'foreground' => 'blue', "underline" => Pango::UNDERLINE_SINGLE)
          tag.signal_connect('event'){ |this, textview, event, iter|
            Lock.synchronize{
              if(event.is_a?(Gdk::EventButton)) and
                  (event.button == 1) and
                  (event.event_type == Gdk::Event::BUTTON_RELEASE) and
                  not(textview.buffer.selection_bounds[2]) then
                proc.call(match)
              elsif(event.is_a?(Gdk::EventMotion)) then
                set_cursor(textview, Gdk::Cursor::HAND2)
              end
            }
            false
          }
          buffer.apply_tag(tag, *buffer.get_range(index, match.split(//u).size))
        }
      }
    end

    def gen_body(message, tags={})
      Lock.synchronize{
        buffer = Gtk::TextBuffer.new
        body = Gtk::TextView.new(buffer)
        msg = message.to_s
        buffer.create_tag('shell', tags)
        buffer.insert(buffer.start_iter, msg, 'shell')
        apply_links(buffer)
        body.editable = false
        body.cursor_visible = false
        body.wrap_mode = Gtk::TextTag::WRAP_CHAR
        body.signal_connect('realize'){ |body|
          Lock.synchronize{
            window = body.get_window(Gtk::TextView::WINDOW_TEXT)
            c = Gdk::Color.new(*get_backgroundcolor.map{|a| a*255})
            Gdk::Colormap.system.alloc_color(c, false, true)
            window.background = c }
          false }
        body.signal_connect('event'){
          Lock.synchronize{ set_cursor(body, Gdk::Cursor::XTERM) }
          false }
        body.signal_connect('button_press_event'){ |widget, event|
          Gtk::Lock.synchronize{ event.button == 3 } }
        body.signal_connect('button_release_event'){ |widget, event|
          Gtk::Lock.synchronize{
            menu_pop(widget, @replies, message) if (event.button == 3) }
          false }
        body }
    end

    def icon(msg, x, y=x)
      Gtk::WebIcon.new(april_fool(msg[:user][:profile_image_url]), x, y)
    end

    def gen_minimumble(msg)
      Lock.synchronize{
        cont = Gtk::HBox.new(false, 8)
        cont.pack_start(icon(msg, 24).top,false)
        cont.pack_start(gen_body(msg, 'foreground' => 'blue', 'font' => "Sans 8")) }
    end

    def gen_header(msg)
      user = msg[:user]
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
      control = Gtk::HBox.new(false, 8).closeup(gen_iob(msg).top).add(gen_body(msg))
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
        signal_connect('realize'){
          style = Gtk::Style.new()
          style.set_bg(Gtk::STATE_NORMAL, *get_backgroundcolor.map{|a| a*255})
          self.style = style
          false } }
    end

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
      Gtk::HBox.new(false, 4).closeup(Gtk::Label.new('ReTweeted by ' + msg[:user][:idname])).
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

    def menu_pop(widget, replies, message)
      Lock.synchronize{
        menu = Gtk::Menu.new
        menu_column = []
        if widget.is_a?(Gtk::TextView) then
          if(widget.buffer.selection_bounds[2]) then
            menu_column << Gtk::MenuItem.new("コピー")
            menu_column.last.signal_connect('activate') { |w|
              widget.copy_clipboard
              false }
          else
            menu_column << Gtk::MenuItem.new("本文をコピー")
            menu_column.last.signal_connect('activate') { |w|
              widget.select_all(true)
              widget.copy_clipboard
              widget.select_all(false)
              false }
          end
        end
        if message.repliable? then
          menu_column << Gtk::MenuItem.new("返信")
          menu_column.last.signal_connect('activate') { |w|
            gen_postbox(replies, message)
            false }
          menu_column << Gtk::MenuItem.new("非公式リツイート")
          menu_column.last.signal_connect('activate') { |w|
            gen_postbox(replies, message, :retweet => true)
            false }
        end
        menu_column.each{|item| menu.append(item) }
        menu.attach_to_widget(widget) {|attach_widgt, mnu| notice "detaching" }
        menu.show_all
        menu.popup(nil, nil, 0, 0) }
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
        sub_button{ menu_pop(self, @mumble.replies, msg) }
        set_buttonback(MUI::Skin.get("overbutton.png"),
                       MUI::Skin.get("overbutton_mouseover.png"))
      end

      def reply
        add(@@buttons[:reply]){ @mumble.gen_postbox(@mumble.replies, @msg) }
      end

      def retweet
        add(@@buttons[:retweet]){ @mumble.gen_postbox(@mumble.replies, @msg, :retweet => true) }
      end

      def etc
        add(@@buttons[:etc]){ @mumble.menu_pop(self, @mumble.replies, @msg) }
      end

      def favorite
        add(@@buttons[:fav][@msg.favorite?], :always_show => @msg.favorite?){ |this, options|
          @msg.favorite(!@msg.favorite?)
          options[:always_show] = @msg[:favorited] = !@msg.favorite?
          [@@buttons[:fav][@msg.favorite?], options]
        }
      end

    end

  end

end
