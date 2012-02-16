# -*- coding: utf-8 -*-

miquire :mui, 'sub_parts_helper'

require 'gtk2'
require 'cairo'

class Gdk::ReplyViewer < Gdk::SubParts
  regist

  attr_reader :icon_width, :icon_height

  def initialize(*args)
    super
    @icon_width, @icon_height, @margin = 24, 24, 2
    @message_got = false
    if message and not helper.visible?
      sid = helper.ssc(:expose_event, helper){
        helper.on_modify
        helper.signal_handler_disconnect(sid)
        false } end
  end

  def render(context)
    if helper.visible? and message
      context.save{
        context.translate(@margin, 0)
        render_main_icon(context)
        context.translate(@icon_width + @margin, 0)
        context.set_source_rgb(*(UserConfig[:mumble_reply_color] || [0,0,0]).map{ |c| c.to_f / 65536 })
        context.show_pango_layout(main_message(context)) } end end

  def height
    if not(helper.destroyed?) and helper.tree.force_retrieve_in_reply_to ? helper.to_message.has_receive_message? : helper.to_message.receive_message
      icon_height
    else
      0 end end

  private

  def message
    if not helper.tree.force_retrieve_in_reply_to
      if @before_height and @before_height != height
        helper.reset_height end
      @before_height = height end
    return @message if @message_got
    if(helper.to_message.has_receive_message?)
      @message ||= lambda{
        result = helper.to_message.receive_message
        if(helper.tree.force_retrieve_in_reply_to and not result)
          parent_message = helper.to_message
          before_height = height
          Thread.new{
            @message_got = true
            @message = parent_message.receive_message(true)
            Delayer.new{
              if not helper.destroyed?
                helper.on_modify
                helper.reset_height if before_height != height end } } end
        result }.call end end

  def escaped_main_text
    Pango.escape(message.to_show) end

  def main_message(context = dummy_context)
    attr_list, text = Pango.parse_markup(escaped_main_text)
    layout = context.create_pango_layout
    layout.width = (width - @icon_width - @margin*3) * Pango::SCALE
    layout.attributes = attr_list
    layout.wrap = Pango::WRAP_CHAR
    layout.font_description = Pango::FontDescription.new(UserConfig[:mumble_reply_font])
    layout.text = text
    layout end

  def render_main_icon(context)
    context.set_source_pixbuf(main_icon)
    context.paint
  end

  def main_icon
    @main_icon ||= Gdk::WebImageLoader.pixbuf(message[:user][:profile_image_url], icon_width, icon_height){ |pixbuf|
      @main_icon = pixbuf
      helper.on_modify } end

end
