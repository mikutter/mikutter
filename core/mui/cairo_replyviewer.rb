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
end
