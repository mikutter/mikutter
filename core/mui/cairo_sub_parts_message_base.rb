# -*- coding: utf-8 -*-

require 'gtk2'
require 'cairo'

=begin rdoc
ナウい引用っぽく _Cairo::MiraclePainter_ のSubPartsとして別の _Message_ を表示するSubPartsを作るときの基底クラス。

= 使い方
このクラスを継承しましょう。
そして、以下のドキュメントを参考に、必要なメソッドをオーバライドします。
=end
class Gdk::SubPartsMessageBase < Gdk::SubParts
  attr_reader :icon_width, :icon_height

  # SubPartsに表示する _Message_ 。
  # 複数表示可能なので、それらを上に表示されるものから順番に返す。
  # サブクラスで処理を実装すること。
  # このメソッドはサブパーツの描画中に何回も呼ばれるので、キャッシュなどで高速化に努めること。
  # ==== Return
  # _Messages_ | _Array_ :: このSubParts上に表示する _Message_
  def messages
    [] end

  # SubParts内の _Message_ の左上に表示するバッジ。
  # サブクラスで処理を実装すること。
  # ==== Args
  # [message] Message
  # ==== Return
  # Gdk::Pixbuf :: _message_ の左上に表示するバッジ画像
  # nil :: バッジを表示しない
  def badge(message)
    nil end

  # 表示している _Message_ がクリックされた時、その _Message_ を引数に呼ばれる。
  # サブクラスで処理を実装すること。
  # ==== Args
  # [e] Gdk::EventButton クリックイベント
  # [message] Message クリックされた _Message_
  def on_click(e, message)
  end

  # SubParts内の _Message_ の背景色を返す
  # ==== Args
  # [message] Message
  # ==== Return
  # Array :: red, green, blueの配列。各要素は0.0..1.0の範囲。
  def background_color(message)
    color = Plugin.filtering(:message_background_color, message, nil).last
    if color.is_a? Array and 3 == color.size
      color.map{ |c| c.to_f / 65536 }
    else
      [1.0]*3 end end

  # :nodoc:
  def initialize(*args)
    super
    @icon_width, @icon_height, @margin, @edge, @badge_radius = 32, 32, 2, 8, 6 end

  # :nodoc:
  def render_messages
    if not helper.destroyed?
      helper.on_modify
      helper.reset_height
      helper.ssc(:click) { |this, e, x, y|
        ofsty = helper.mainpart_height
        helper.subparts.each { |part|
          break if part == self
          ofsty += part.height }
        if ofsty <= y and (ofsty + height) >= y
          my = 0
          messages.each { |m|
            my += message_height(m)
            if y <= ofsty + my
              on_click(e, m)
              break end } end } end end

  # :nodoc:
  def render(context)
    if messages and not messages.empty?
      messages.inject(0) { |base_y, message|
        render_single_message(message, context, base_y) } end end

  # :nodoc:
  def height
    if not helper.destroyed? and messages and not messages.empty?
      messages.inject(0) { |s, m| s + message_height(m) }
    else
      0 end end

  private

  def render_single_message(message, context, base_y)
    render_outline(message, context, base_y)
    render_header(message, context, base_y)
    context.save do
      context.translate(@margin + @edge, @margin + @edge + base_y)
      context.set_source_pixbuf(main_icon(message))
      context.paint
      context.save do
        context.translate(icon_width + @margin*2, header_left(message).size[1] / Pango::SCALE)
        context.set_source_rgb(*([0,0,0]).map{ |c| c.to_f / 65536 })
        pango_layout = main_message(message, context)
        if pango_layout.line_count <= 3
          context.show_pango_layout(pango_layout)
        else
          line_height = pango_layout.pixel_size[1] / pango_layout.line_count + pango_layout.spacing / Pango::SCALE
          context.translate(0, line_height*0.75)
          (0...3).map(&pango_layout.method(:get_line)).each do |line|
            context.show_pango_layout_line(line)
            context.translate(0, line_height) end end end
      render_badge(message, context) end

    base_y + message_height(message) end

  def message_height(message)
    [icon_height, (header_left(message).pixel_size[1] + main_message_height(message))].max + (@margin + @edge) * 2
  end

  def main_message_height(message)
    pango_layout = main_message(message)
    result = pango_layout.pixel_size[1]
    if pango_layout.line_count <= 3
      result
    else
      (result / pango_layout.line_count + pango_layout.spacing/Pango::SCALE) * 3 end end

  # ヘッダ（左）のための Pango::Layout のインスタンスを返す
  def header_left(message, context = dummy_context)
    attr_list, text = Pango.parse_markup("<b>#{Pango.escape(message[:user][:idname])}</b> #{Pango.escape(message[:user][:name] || '')}")
    layout = context.create_pango_layout
    layout.attributes = attr_list
    layout.font_description = Pango::FontDescription.new(UserConfig[:mumble_basic_font])
    layout.text = text
    layout end

  # ヘッダ（右）のための Pango::Layout のインスタンスを返す
  def header_right(message, context = dummy_context)
    now = Time.now
    hms = if message[:created].year == now.year && message[:created].month == now.month && message[:created].day == now.day
            message[:created].strftime('%H:%M:%S'.freeze)
          else
            message[:created].strftime('%Y/%m/%d %H:%M:%S'.freeze)
          end
    attr_list, text = Pango.parse_markup("<span foreground=\"#999999\">#{Pango.escape(hms)}</span>".freeze)
    layout = context.create_pango_layout
    layout.attributes = attr_list
    layout.font_description = Pango::FontDescription.new(UserConfig[:mumble_basic_font])
    layout.text = text
    layout.alignment = Pango::ALIGN_RIGHT
    layout end

  def render_header(message, context, base_y)
    header_w = width - @icon_width - @margin*3 - @edge*2
    context.save{
      context.translate(@icon_width + @margin*2 + @edge, @margin + @edge + base_y)
      context.set_source_rgb(0,0,0)
      hl_layout, hr_layout = header_left(message, context), header_right(message, context)
      context.show_pango_layout(hl_layout)
      context.save{
        context.translate(header_w - hr_layout.pixel_size[0], 0)
        if hl_layout.pixel_size[0] > header_w - hr_layout.pixel_size[0] - 20
          r, g, b = background_color(message)
          grad = Cairo::LinearPattern.new(-20, base_y, hr_layout.pixel_size[0] + 20, base_y)
          grad.add_color_stop_rgba(0.0, r, g, b, 0.0)
          grad.add_color_stop_rgba(20.0 / (hr_layout.pixel_size[0] + 20), r, g, b, 1.0)
          grad.add_color_stop_rgba(1.0, r, g, b, 1.0)
          context.rectangle(-20, 0, hr_layout.pixel_size[0] + 20, hr_layout.pixel_size[1])
          context.set_source(grad)
          context.fill() end
        context.show_pango_layout(hr_layout) } }
  end

  def main_message(message, context = dummy_context)
    attr_list, text = Pango.parse_markup(Pango.escape(message.to_show))
    layout = context.create_pango_layout
    layout.width = (width - @icon_width - @margin*3 - @edge*2) * Pango::SCALE
    layout.attributes = attr_list
    layout.wrap = Pango::WRAP_CHAR
    layout.font_description = Pango::FontDescription.new(UserConfig[:mumble_reply_font])
    layout.text = text
    layout end

  def render_outline(message, context, base_y)
    mh = message_height(message)
    context.save {
      context.pseudo_blur(4) {
        context.fill {
          context.set_source_rgb(*([32767, 32767, 32767]).map{ |c| c.to_f / 65536 })
          context.rounded_rectangle(@edge, @edge + base_y, width - @edge*2, mh - @edge*2, 4)
        }
      }
      context.fill {
        context.set_source_rgb(*background_color(message))
        context.rounded_rectangle(@edge, @edge + base_y, width - @edge*2, mh - @edge*2, 4)
      }
    }
  end

  def render_badge(message, context)
    badge_pixbuf = badge(message)
    if badge_pixbuf
      context.save {
        context.pseudo_blur(4) {
          context.fill {
            context.set_source_rgb(*([32767, 32767, 32767]).map{ |c| c.to_f / 65536 })
            context.circle(0, 0, @badge_radius)
          }
        }
        context.fill {
          context.set_source_rgb(*background_color(message))
          context.circle(0, 0, @badge_radius)
        }
      }
      context.translate(-@badge_radius, -@badge_radius)
      context.set_source_pixbuf(badge_pixbuf)
      context.paint end
  end

  def main_icon(message)
    Gdk::WebImageLoader.pixbuf(message[:user][:profile_image_url], icon_width, icon_height){ |pixbuf|
      helper.on_modify } end
end
