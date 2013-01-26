# -*- coding: utf-8 -*-
miquire :mui, 'extension', 'contextmenu'
miquire :core, 'plugin'
miquire :miku, 'miku'

require 'gtk2'
require 'uri'

class Gtk::IntelligentTextview < Gtk::TextView

  attr_accessor :fonts, :get_background

  # @@wayofopenlink = MIKU::Cons.list([URI.regexp(['http','https']), lambda{ |url, cancel|
  #                                      Gtk.openurl(url) }].freeze).freeze

  @@linkrule = MIKU::Cons.list([URI.regexp(['http','https']),
                                lambda{ |u, clicked| self.openurl(u) },
                                lambda{ |u, clicked|
                                  Gtk::ContextMenu.new(['リンクのURLをコピー', ret_nth, lambda{ |opt, w| Gtk::Clipboard.copy(u) }],
                                                       ['開く', ret_nth, lambda{ |opt, w| self.openurl(u) }]).
                                  popup(clicked, true)}])
  @@widgetrule = []

  # URLを開く方法を追加する。
  # 追加に成功したらtrueを返す。
  # def self.addopenway(condition, &open)
  #   if(type_check(condition => :===, open => :call))
  #     @@wayofopenlink = MIKU::Cons.new([condition, open].freeze, @@wayofopenlink).freeze
  #     true end end

  def self.addlinkrule(reg, leftclick, rightclick=nil)
    @@linkrule = MIKU::Cons.new([reg, leftclick, rightclick].freeze, @@linkrule).freeze end

  def self.addwidgetrule(reg, widget = nil)
    @@widgetrule = @@widgetrule.unshift([reg, (widget or Proc.new)]) end

  # URLを開く
  def self.openurl(url)
    # gen_openurl_proc(url).call
    Gtk::TimeLine.openurl(url)
    false end

  # def self.gen_openurl_proc(url, way_of_open_link = @@wayofopenlink)
  #   way_of_open_link.freeze
  #   lambda{
  #     way_of_open_link.each_with_index{ |way, index|
  #     condition, open = *way
  #     if(condition === url)
  #       open.call(url, gen_openurl_proc(url, way_of_open_link[(index+1)..(way_of_open_link.size)]))
  #       break end } } end

  def initialize(msg = nil, default_fonts = {}, *args)
    @fonts = default_fonts
    @get_background = lambda{ parent.style.bg(Gtk::STATE_NORMAL) }
    super(*args)
    self.editable = false
    self.cursor_visible = false
    self.wrap_mode = Gtk::TextTag::WRAP_CHAR
    gen_body(msg) if msg
  end

  # TODO プライベートにする
  def set_cursor(textview, cursor)
    textview.get_window(Gtk::TextView::WINDOW_TEXT).set_cursor(Gdk::Cursor.new(cursor))
  end

  def bg_modifier(color = @get_background.call)
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
    type_strict msg => String
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
    type_strict msg => String, fonts => Hash
    tags = fonts2tags(fonts)
    tag_shell = buffer.create_tag('shell', fonts2tags(fonts))
    buffer.insert(buffer.start_iter, msg, 'shell')
    apply_links
    apply_inner_widget
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
#    self.signal_connect('button_release_event'){ |widget, event|
#       Gtk::Lock.synchronize{
#         menu_pop(widget) if (event.button == 3) }
#     false }
  end

  def create_tag_ifnecessary(tagname, buffer, leftclick, rightclick)
    tag = buffer.create_tag(tagname, "underline" => Pango::UNDERLINE_SINGLE)
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
        match = match.to_s
        index = buffer.text[0, index].size
        create_tag_ifnecessary(match, buffer, left, right) if not buffer.tag_table.lookup(match)
        range = buffer.get_range(index, match.size)
        buffer.apply_tag(match, *range)
      } } end

  def apply_inner_widget
    offset = 0
    @@widgetrule.each{ |param|
      reg, widget_generator = param
      buffer.text.each_matches(reg) { |match, index|
        match = match.to_s
        index = [buffer.text.size, index].min
        range = buffer.get_range(index, match.size + offset)
        widget = widget_generator.call(match)
        if widget
          self.add_child_at_anchor(widget, buffer.create_child_anchor(range[1]))
          offset += 1 end } } end
end

Plugin.create :gtk_intelligent_textview do
  on_entity_linkrule_added do |rule|
    ::Gtk::IntelligentTextview.addlinkrule(rule[:regexp], lambda{ |seg, tv| rule[:callback].call(face: seg, url: seg, textview: tv) }) if rule[:regexp]
  end
end
