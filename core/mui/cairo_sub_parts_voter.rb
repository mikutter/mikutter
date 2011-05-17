# -*- coding: utf-8 -*-

miquire :mui, 'sub_parts_helper'

require 'gtk2'
require 'cairo'

class Gdk::SubPartsVoter < Gdk::SubParts

  attr_reader :votes, :icon_width, :icon_height, :margin

  def initialize(*args)
    super
    @icon_width, @icon_height, @margin, @votes, @user_icon = 24, 24, 2, helper.message.favorited_by.to_a, Hash.new
    if not(helper.visible? or @votes.empty?)
      sid = helper.signal_connect(:expose_event){
        helper.on_modify
        helper.signal_handler_disconnect(sid)
        false } end end

  def render(context)
    if(not @votes.empty?)
      if helper.visible?
        context.save{
          context.translate(@margin, 0)
          context.set_source_rgb(*(UserConfig[:mumble_basic_color] || [0,0,0]).map{ |c| c.to_f / 65536 })
          plc = pl_count(context)
          context.save{
            context.translate(0, (icon_width/2) - (plc.size[1] / Pango::SCALE / 2))
            context.show_pango_layout(plc) }
          context.translate(plc.size[0] / Pango::SCALE, 0)
          votes.each{ |user|
            render_icon(context, user) } } end end
    @last_height = height end

  def height
    if @votes.empty?
      0
    else
      icon_height end end

  def add(new)
    if not @votes.include?(new)
      before_height = height
      @votes << new
      if(before_height == height)
        helper.on_modify
      else
        helper.reset_height end
      self end end
  alias << add

  private

  def render_icon(context, user)
    context.set_source_pixbuf(user_icon(user))
    context.paint
    context.translate(icon_width, 0)
  end

  def user_icon(user)
    @user_icon[user[:id]] ||= Gtk::WebIcon.get_icon_pixbuf(user[:profile_image_url], icon_width, icon_height){ |pixbuf|
      @user_icon[user[:id]] = pixbuf
      helper.on_modify } end

  def pl_count(context = dummy_context)
    layout = context.create_pango_layout
    layout.wrap = Pango::WRAP_CHAR
    layout.font_description = Pango::FontDescription.new(UserConfig[:mumble_basic_font])
    layout.text = "#{votes.size} fav"
    layout
  end

  Delayer.new{
    Plugin.create(:core).add_event(:favorite){ |service, user, message|
      Gdk::MiraclePainter.findbymessage(message).each{ |mp|
        mp.subparts.find{ |sp| sp.class == Gdk::SubPartsFavorite }.add(user)
        mp.on_modify } } }

end
