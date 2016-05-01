# -*- coding: utf-8 -*-

miquire :mui, 'sub_parts_message_base'

UserConfig[:quote_present_policy] ||= %i<header icon edge>
UserConfig[:quote_edge] ||= :floating

class Gdk::SubPartsQuote < Gdk::SubPartsMessageBase
  register

  def messages
    @messages end

  def on_click(e, message)
    case e.button
    when 1
      Plugin.filtering(:command, {}).first[:smartthread][:exec].call(Struct.new(:messages).new([message]))
    end end

  def initialize(*args)
    super
    if helper.message.quoting?
      Thread.new(helper.message) { |m|
        m.quoting_messages(true)
      }.next{ |quoting|
        @messages = Messages.new(quoting).freeze
        render_messages
      }.terminate('コメント付きリツイート描画中にエラーが発生しました') end end

  def badge(_message)
    Gdk::Pixbuf.new(Skin.get('quote.png'), @badge_radius*2, @badge_radius*2) end

  def background_color(message)
    color = Plugin.filtering(:subparts_quote_background_color, message, UserConfig[:quote_background_color]).last
    if color.is_a? Array and 3 == color.size
      color.map{ |c| c.to_f / 65536 }
    else
      [1.0]*3 end end

  def main_text_color(message)
    if UserConfig[:quote_text_color]
      UserConfig[:quote_text_color].map{ |c| c.to_f / 65536 }
    else
      super end end

  def main_text_font(message)
    Pango::FontDescription.new(UserConfig[:quote_text_font]) end

  def header_left_content(*args)
    if show_header?
      super end end

  def header_right_content(*args)
    if show_header?
      super end end

  def icon_width
    if show_icon?
      UserConfig[:quote_icon_size] || super
    else
      0 end end

  def icon_height
    if show_icon?
      UserConfig[:quote_icon_size] || super
    else
      0 end end

  def text_max_line_count(message)
    UserConfig[:quote_text_max_line_count] || super end

  def render_outline(message, context, base_y)
    unless show_edge?
      @edge = 2
      return end
    @edge = 8
    case UserConfig[:quote_edge]
    when :floating
      render_outline_floating(message, context, base_y)
    when :solid
      render_outline_solid(message, context, base_y)
    when :flat
      render_outline_flat(message, context, base_y) end end

  def render_badge(message, context)
    return unless show_edge?
    case UserConfig[:quote_edge]
    when :floating
      render_badge_floating(message, context)
    when :solid
      render_badge_solid(message, context)
    when :flat
      render_badge_flat(message, context) end end

  def show_header?
    (UserConfig[:quote_present_policy] || []).include?(:header) end

  def show_icon?
    (UserConfig[:quote_present_policy] || []).include?(:icon) end

  def show_edge?
    (UserConfig[:quote_present_policy] || []).include?(:edge) end
end




