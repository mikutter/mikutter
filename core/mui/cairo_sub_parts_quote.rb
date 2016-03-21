# -*- coding: utf-8 -*-

miquire :mui, 'sub_parts_message_base'

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
end
