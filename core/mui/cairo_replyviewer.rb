# -*- coding: utf-8 -*-

miquire :mui, 'sub_parts_message_base'

class Gdk::ReplyViewer < Gdk::SubPartsMessageBase
  register

  attr_reader :messages

  def initialize(*args)
    super
    if helper.message.has_receive_message?
      helper.message.replyto_source_d(true).next{ |reply|
        @messages = Messages.new([reply]).freeze
        render_messages
      }.terminate('リプライ描画中にエラーが発生しました') end end

  def badge(_message)
    Gdk::Pixbuf.new(Skin.get('reply.png'), @badge_radius*2, @badge_radius*2) end

  def background_color(message)
    color = Plugin.filtering(:subparts_replyviewer_background_color, message, nil).last
    if color.is_a? Array and 3 == color.size
      color.map{ |c| c.to_f / 65536 }
    else
      [1.0]*3 end end
end
