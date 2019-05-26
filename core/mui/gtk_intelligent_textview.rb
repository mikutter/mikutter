# -*- coding: utf-8 -*-
miquire :mui, 'extension', 'contextmenu'
miquire :core, 'plugin'
miquire :miku, 'miku'

require 'gtk2'
require 'uri'

class Gtk::IntelligentTextview < Gtk::TextView
  extend Gem::Deprecate

  attr_accessor :fonts
  attr_writer :style_generator
  alias :get_background= :style_generator=
  deprecate :get_background=, "style_generator=", 2017, 02

  @@linkrule = MIKU::Cons.list([URI.regexp(['http','https']),
                                lambda{ |u, clicked| self.openurl(u) },
                                lambda{ |u, clicked|
                                  Gtk::ContextMenu.new(['リンクのURLをコピー', ret_nth, lambda{ |opt, w| Gtk::Clipboard.copy(u) }],
                                                       ['開く', ret_nth, lambda{ |opt, w| self.openurl(u) }]).
                                  popup(clicked, true)}])
  @@widgetrule = []

  def self.addlinkrule(reg, leftclick, rightclick=nil)
    @@linkrule = MIKU::Cons.new([reg, leftclick, rightclick].freeze, @@linkrule).freeze end

  def self.addwidgetrule(reg, widget = nil)
    @@widgetrule = @@widgetrule.unshift([reg, (widget or Proc.new)]) end

  # URLを開く
  def self.openurl(url)
    # gen_openurl_proc(url).call
    Gtk::TimeLine.openurl(url)
    false end

  def initialize(msg = nil, default_fonts = {}, *rest, style: nil)
    super(*rest)
    @fonts = default_fonts
    @style_generator = style
    self.editable = false
    self.cursor_visible = false
    self.wrap_mode = Gtk::TextTag::WRAP_CHAR
    gen_body(msg) if msg
  end

  # このウィジェットの背景色を返す
  # ==== Return
  # Gtk::Style
  def style_generator
    if @style_generator.respond_to? :to_proc
      @style_generator.to_proc.call
    elsif @style_generator
      @style_generator
    else
      parent.style.bg(Gtk::STATE_NORMAL)
    end
  end
  alias :get_background :style_generator
  deprecate :get_background, "style_generator", 2017, 02

  # TODO プライベートにする
  def set_cursor(textview, cursor)
    textview.get_window(Gtk::TextView::WINDOW_TEXT).set_cursor(Gdk::Cursor.new(cursor))
  end

  def bg_modifier(color = style_generator)
    if color.is_a? Gtk::Style
      self.style = color
    elsif get_window(Gtk::TextView::WINDOW_TEXT).respond_to?(:background=)
      get_window(Gtk::TextView::WINDOW_TEXT).background = color end
    queue_draw
    false end

  # 新しいテキスト _msg_ に内容を差し替える。
  # ==== Args
  # [msg] 表示する文字列
  # ==== Return
  # self
  def rewind(msg)
    set_buffer(Gtk::TextBuffer.new)
    gen_body(msg)
  end

  private

  def fonts2tags(fonts)
    tags = Hash.new
    tags['font'] = UserConfig[fonts['font']] if fonts.has_key?('font')
    if fonts.has_key?('foreground')
      tags['foreground_gdk'] = Gdk::Color.new(*UserConfig[fonts['foreground']]) end
    tags
  end

  def gen_body(msg, fonts={})
    tag_shell = buffer.create_tag('shell', fonts2tags(fonts))
    case msg
    when String
      type_strict fonts => Hash
      tags = fonts2tags(fonts)
      buffer.insert(buffer.start_iter, msg, 'shell')
      apply_links
      apply_inner_widget
    when Enumerator # score
      pos = buffer.end_iter
      msg.each_with_index do |note, index|
        if clickable?(note)
          tagname = "tag#{index}"
          create_tag_ifnecessary(tagname, buffer,
                                 ->(_tagname, _textview){
                                   Plugin.call(:open, note)
                                 }, nil)
          start = pos.offset
          buffer.insert(pos, note.description)
          buffer.apply_tag(tagname, buffer.get_iter_at_offset(start), pos)
        else
          buffer.insert(pos, note.description, 'shell')
        end
      end
    end
    set_events(tag_shell)
    self
  end

  def set_events(tag_shell)
    self.signal_connect('realize'){
      self.parent.signal_connect('style-set'){ bg_modifier } }
    self.signal_connect('realize'){ bg_modifier }
    self.signal_connect('visibility-notify-event'){
      if fonts['font'] and tag_shell.font != UserConfig[fonts['font']]
        tag_shell.font = UserConfig[fonts['font']] end
      if fonts['foreground'] and tag_shell.foreground_gdk.to_s != UserConfig[fonts['foreground']]
        tag_shell.foreground_gdk = Gdk::Color.new(*UserConfig[fonts['foreground']]) end
      false }
    self.signal_connect('event'){
      set_cursor(self, Gdk::Cursor::XTERM)
      false }
  end

  def create_tag_ifnecessary(tagname, buffer, leftclick, rightclick)
    tag = buffer.create_tag(tagname, "underline" => Pango::Underline::SINGLE)
    tag.signal_connect('event'){ |this, textview, event, iter|
      result = false
      if(event.is_a?(Gdk::EventButton)) and
          (event.event_type == Gdk::Event::BUTTON_RELEASE) and
          not(textview.buffer.selection_bounds[2])
        if (event.button == 1 and leftclick)
          leftclick.call(tagname, textview)
        elsif(event.button == 3 and rightclick)
          rightclick.call(tagname, textview)
          result = true end
      elsif(event.is_a?(Gdk::EventMotion))
        set_cursor(textview, Gdk::Cursor::HAND2)
      end
      result }
    tag end

  def apply_links
    @@linkrule.each{ |param|
      reg, left, right = param
      buffer.text.scan(reg) {
        match = Regexp.last_match
        index = buffer.text[0, match.begin(0)].size
        body = match.to_s.freeze
        create_tag_ifnecessary(body, buffer, left, right) if not buffer.tag_table.lookup(body)
        range = buffer.get_range(index, body.size)
        buffer.apply_tag(body, *range)
      } } end

  def apply_inner_widget
    offset = 0
    @@widgetrule.each{ |param|
      reg, widget_generator = param
      buffer.text.scan(reg) { |match|
        match = Regexp.last_match
        index = [buffer.text.size, match.begin(0)].min
        body = match.to_s.freeze
        range = buffer.get_range(index, body.size + offset)
        widget = widget_generator.call(body)
        if widget
          self.add_child_at_anchor(widget, buffer.create_child_anchor(range[1]))
          offset += 1 end } } end

  def clickable?(model)
    has_model_intent = Enumerator.new {|y| Plugin.filtering(:intent_select_by_model_slug, model.class.slug, y) }.first
    return true if has_model_intent
    Enumerator.new {|y|
      Plugin.filtering(:model_of_uri, model.uri, y)
    }.any?{|model_slug|
      Enumerator.new {|y| Plugin.filtering(:intent_select_by_model_slug, model_slug, y) }.first
    }
  end
end
