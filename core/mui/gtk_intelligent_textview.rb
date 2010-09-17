# -*- coding: utf-8 -*-
miquire :mui, 'extension'
miquire :mui, 'contextmenu'
miquire :miku, 'miku'

require 'gtk2'
require 'uri'

class Gtk::IntelligentTextview < Gtk::TextView
  attr_accessor :fonts, :get_background

  @@linkrule = MIKU::Cons.list([URI.regexp(['http','https']),
                                lambda{ |u, clicked| Gtk::openurl u},
                                lambda{ |u, clicked|
                                  Gtk::ContextMenu.new(['ブラウザで開く', ret_nth(),
                                                        lambda{ |opt, w|
                                                          Gtk::openurl(u) }],
                                                       ['リンクのURLをコピー', ret_nth(),
                                                        lambda{ |opt, w|
                                                          Gtk::Clipboard.copy(u) }]).popup(clicked, true)}])
  @@widgetrule = []

  def self.addlinkrule(reg, leftclick, rightclick=nil)
    @@linkrule = MIKU::Cons.new([reg, leftclick, rightclick], @@linkrule) end

  def self.addwidgetrule(reg, widget = nil)
    @@widgetrule = @@widgetrule.unshift([reg, (widget or Proc.new)]) end

  def initialize(msg, default_fonts = {}, *args)
    assert_type(String, msg)
    @fonts = default_fonts
    @get_background = lambda{ parent.style.bg(Gtk::STATE_NORMAL) }
    super(*args)
    self.editable = false
    self.cursor_visible = false
    self.wrap_mode = Gtk::TextTag::WRAP_CHAR
    gen_body(msg)
  end

  # TODO プライベートにする
  def set_cursor(textview, cursor)
    textview.get_window(Gtk::TextView::WINDOW_TEXT).set_cursor(Gdk::Cursor.new(cursor))
  end

  private

  def fonts2tags(fonts)
    tags = Hash.new
    tags['font'] = UserConfig[fonts['font']] if fonts.has_key?('font')
    if fonts.has_key?('foreground')
      tags['foreground_gdk'] = Gdk::Color.new(*UserConfig[fonts['foreground']]) end
    tags
  end

  def bg_modifier
    color = @get_background.call
    if color.is_a? Gtk::Style
      self.style = color
    elsif get_window(Gtk::TextView::WINDOW_TEXT).respond_to?(:background=)
      get_window(Gtk::TextView::WINDOW_TEXT).background = color end
    false end

  def gen_body(msg, fonts={})
    tags = fonts2tags(fonts)
    Gtk::Lock.synchronize{
      tag_shell = buffer.create_tag('shell', fonts2tags(fonts))
      buffer.insert(buffer.start_iter, msg, 'shell')
      apply_links
      apply_inner_widget
      set_events(tag_shell)
      self }
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
    self.signal_connect('button_release_event'){ |widget, event|
#       Gtk::Lock.synchronize{
#         menu_pop(widget) if (event.button == 3) }
      false } end

  def create_tag_ifnecessary(tagname, buffer, leftclick, rightclick)
    tag = buffer.create_tag(tagname, 'foreground' => 'blue', "underline" => Pango::UNDERLINE_SINGLE)
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
      buffer.text.each_matches(reg) { |match, index|
        index = buffer.text[0, index].strsize
        create_tag_ifnecessary(match, buffer, left, right) if not buffer.tag_table.lookup(match)
        range = buffer.get_range(index, match.strsize)
        buffer.apply_tag(match, *range)
      } } end

  def apply_inner_widget
    offset = 0
    @@widgetrule.each{ |param|
      reg, widget_generator = param
      buffer.text.each_matches(reg) { |match, index|
        index = buffer.text[0, index].strsize
        range = buffer.get_range(index, match.strsize + offset)
        widget = widget_generator.call(match)
        if widget
          self.add_child_at_anchor(widget, buffer.create_child_anchor(range[1]))
          offset += 1 end } } end
end
