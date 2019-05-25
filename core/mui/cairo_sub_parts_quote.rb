# -*- coding: utf-8 -*-

miquire :mui, 'sub_parts_message_base'

class Gdk::SubPartsQuote < Gdk::SubPartsMessageBase
  EDGE_ABSENT_SIZE = 2
  EDGE_PRESENT_SIZE = 8

  register

  def messages
    @messages end

  def on_click(e, message)
    case e.button
    when 1
      case UserConfig[:quote_clicked_action]
      when :open
        Plugin.call(:open, message)
      when :smartthread
        Plugin.call(:open_smartthread, [message]) end
    end end

  def initialize(*args)
    super
    @edge = show_edge? ? EDGE_PRESENT_SIZE : EDGE_ABSENT_SIZE
    promise_list = helper.score.select{ |note|
      note.respond_to?(:reference)
    }.map{ |note|
      note.reference&.uri || note.uri
    }.select{ |u|
      u.is_a?(Diva::URI)
    }.map{ |target_uri|
      model_class = Enumerator.new{ |y|
        Plugin.filtering(:model_of_uri, target_uri, y)
      }.lazy.map{ |model_slug|
        Diva::Model(model_slug)
      }.find{ |mc|
        mc.spec.timeline
      }
      Delayer.Deferred.new{ model_class.find_by_uri(target_uri) } if model_class
    }.compact
    if !promise_list.empty?
      Delayer::Deferred.when(promise_list).next{ |quoting|
        quoting = quoting.compact
        if !quoting.empty?
          @messages = quoting.freeze
          render_messages
        end
      }.terminate('コメント付きリツイート描画中にエラーが発生しました')
    end
  end

  def edge
    if show_edge?
      unless @edge == EDGE_PRESENT_SIZE
        @edge = EDGE_PRESENT_SIZE
        helper.reset_height end
    else
      unless @edge == EDGE_ABSENT_SIZE
        @edge = EDGE_ABSENT_SIZE
        helper.reset_height end end
    @edge end

  def badge(_message)
    Skin[:quote].pixbuf(width: @badge_radius*2, height: @badge_radius*2) end

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
    helper.font_description(UserConfig[:quote_text_font])
  end

  def header_left_content(*args)
    if show_header?
      super end end

  def header_right_content(*args)
    if show_header?
      super end end

  def icon_size
    if show_icon?
      if UserConfig[:quote_icon_size]
        Gdk::Rectangle.new(0, 0, UserConfig[:quote_icon_size], UserConfig[:quote_icon_size])
      else
        super end end end

  def text_max_line_count(message)
    UserConfig[:quote_text_max_line_count] || super end

  def render_outline(message, context, base_y)
    return unless show_edge?
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




