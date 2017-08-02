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
  extend Memoist

  DEFAULT_ICON_SIZE = 32

  # SubPartsに表示する _Message_ 。
  # 複数表示可能なので、それらを上に表示されるものから順番に返す。
  # サブクラスで処理を実装すること。
  # このメソッドはサブパーツの描画中に何回も呼ばれるので、キャッシュなどで高速化に努めること。
  # ==== Return
  # _Array_ :: このSubParts上に表示する _Message_
  def messages
    [] end

  # ヘッダの左の、Screen name、名前が表示されている場所に表示するテキスト。
  # オーバライドしなければ、 _message_ の投稿者のscreen nameと名前が表示される。
  # nilを返した場合、ヘッダは表示されない。この場合、ヘッダ右も表示されない。
  # ==== Args
  # [message] Message 表示するMessage
  # ==== Return
  # 次の3つの値またはnil（ヘッダ左を使用しない場合）
  # [String] 表示する文字列
  # [Pango::FontDescription] フォント情報
  # [Pango::Attribute] マークアップ情報
  def header_left_content(message)
    attr_list, text = Pango.parse_markup("<b>#{Pango.escape(message[:user][:idname])}</b> #{Pango.escape(message[:user][:name] || '')}")
    return text, header_left_font(message), attr_list end

  # ヘッダ左に使用するフォントを返す
  # ==== Args
  # [message] Message 表示するMessage
  # ==== Return
  # [Pango::FontDescription] フォント情報
  def header_left_font(message)
    default_font end

  # ヘッダの右の、タイムスタンプが表示されているところに表示するテキスト。
  # オーバーライドしなければ、 _message_ のタイムスタンプが表示される。
  # 表示される時に、 Pango.escape を通るので、この戻り値がエスケープを考慮する必要はないが、装飾を指定することはできない。
  # ==== Args
  # [message] Message 対象のMessage
  # ==== Return
  # [String] 表示する文字列。
  def header_right_text(message)
    now = Time.now
    if message[:created].year == now.year && message[:created].month == now.month && message[:created].day == now.day
      message[:created].strftime('%H:%M:%S'.freeze)
    else
      message[:created].strftime('%Y/%m/%d %H:%M:%S'.freeze) end end

  # Gdk::SubPartsMessageBase#header_right_text にマークアップを足した文字列を返す。
  # 通常は header_right_text をオーバライドするようにし、
  # テキストがエスケープされるのが問題になる場合は、こちらをオーバライドする。
  # nilを返した場合、ヘッダ右は表示されない。この場合、ヘッダ左のみが表示される。
  # ヘッダ自体を消す方法については、 Gdk::SubPartsMessageBase#header_left_text を参照
  # ==== Args
  # [message] Message 対象のMessage
  # ==== Return
  # 次の3つの値またはnil（ヘッダ右を使用しない場合）
  # [String] 表示する文字列
  # [Pango::FontDescription] フォント情報
  # [Pango::Attribute] マークアップ情報
  def header_right_content(message)
    attr_list, text = Pango.parse_markup("<span foreground=\"#999999\">#{Pango.escape(header_right_text(message))}</span>")
    return text, header_right_font(message), attr_list end

  # ヘッダ右に使用するフォントを返す
  # ==== Args
  # [message] Message 表示するMessage
  # ==== Return
  # [Pango::FontDescription] フォント情報
  def header_right_font(message)
    default_font end

  # SubParts内の _Message_ の左上に表示するバッジ。
  # サブクラスで処理を実装すること。
  # ==== Args
  # [message] Message
  # ==== Return
  # 以下の値のいずれか一つ
  # GdkPixbuf::Pixbuf :: _message_ の左上に表示するバッジ画像
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
    color = Plugin.filtering(:message_background_color, helper, nil).last
    if color.is_a? Array and 3 == color.size
      color.map{ |c| c.to_f / 65536 }
    else
      [1.0]*3 end end

  # SubParts内の _Message_ の枠の色を返す
  # ==== Args
  # [message] Message
  # ==== Return
  # Array :: red, green, blueの配列。各要素は0.0..1.0の範囲。
  def edge_color(message)
    [0.5]*3 end

  # アイコンのサイズを返す。
  # ==== Return
  # [Gdk::Rectangle] サイズ(px)。xとyは無視され、widthとheightのみが利用される
  # [nil] アイコンを表示しない
  def icon_size
    Gdk::Rectangle.new(0, 0, DEFAULT_ICON_SIZE, DEFAULT_ICON_SIZE) end

  # _message_ の本文のテキスト色を返す
  # ==== Args
  # [message] Message
  # ==== Return
  # Array :: red, green, blueの配列。各要素は0.0..1.0の範囲。
  def main_text_color(message)
    ([0,0,0]).map{ |c| c.to_f / 65536 } end

  # 本文使用するフォントを返す
  # ==== Args
  # [message] Message 表示するMessage
  # ==== Return
  # [Pango::FontDescription] フォント情報
  def main_text_font(message)
    default_font end

  # 本文の最大表示行数を返す。
  # この行数を超えた行は表示されない
  # ==== Args
  # [message] Message 表示するMessage
  # ==== Return
  # Fixnum 行数
  def text_max_line_count(message)
    3 end

  # :nodoc:
  memoize def default_font
    Pango::FontDescription.new(UserConfig[:reply_text_font]) end

  attr_reader :margin

  attr_reader :edge

  # Fixnum 枠線の太さ(px)
  attr_reader :border_weight

  # Fixnum バッジの半径(px)
  attr_reader :badge_radius

  # :nodoc:
  def initialize(*args)
    super
    @margin, @edge, @border_weight, @badge_radius = 2, 8, 1, 6 end

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

  def icon_width
    size = icon_size
    if size
      size.width
    else
      0 end end

  def icon_height
    size = icon_size
    if size
      size.height
    else
      0 end end

  def render_single_message(message, context, base_y)
    render_outline(message, context, base_y)
    _header_width, header_height = render_header(message, context, base_y)
    context.save do
      context.translate(margin + edge, margin + edge + base_y)
      render_icon(message, context)
      context.save do
        context.translate(icon_width + margin*2, header_height || 0)
        context.set_source_rgb(*main_text_color(message))
        pango_layout = main_message(message, context)
        if pango_layout.line_count <= text_max_line_count(message)
          context.show_pango_layout(pango_layout)
        else
          line_height = pango_layout.pixel_size[1] / pango_layout.line_count + pango_layout.spacing / Pango::SCALE
          context.translate(0, line_height*0.75)
          (0...text_max_line_count(message)).map(&pango_layout.method(:get_line)).each do |line|
            context.show_pango_layout_line(line)
            context.translate(0, line_height) end end end
      render_badge(message, context) end

    base_y + message_height(message) end

  def message_height(message)
    header_height = [0, *[header_left(message), header_right(message)].compact.map{|h|
                       h.pixel_size[1]}].max
    [icon_height, (header_height + main_message_height(message))].max + (margin + edge) * 2 end

  def main_message_height(message)
    pango_layout = main_message(message)
    result = pango_layout.pixel_size[1]
    if pango_layout.line_count <= text_max_line_count(message)
      result
    else
      (result / pango_layout.line_count) * text_max_line_count(message) + pango_layout.spacing/Pango::SCALE * 2 end end

  # ヘッダ（左）のための Pango::Layout のインスタンスを返す
  def header_left(message, context = dummy_context)
    text, font, attr_list = header_left_content(message)
    if text
      layout = context.create_pango_layout
      layout.attributes = attr_list if attr_list
      layout.font_description = font if font
      layout.text = text
      layout end end

  # ヘッダ（右）のための Pango::Layout のインスタンスを返す
  def header_right(message, context = dummy_context)
    text, font, attr_list = header_right_content(message)
    if text
      layout = context.create_pango_layout
      layout.attributes = attr_list if attr_list
      layout.font_description = font if font
      layout.text = text
      layout.alignment = Pango::ALIGN_RIGHT
      layout end end

  def render_header(message, context, base_y)
    context.save do
      context.translate(icon_width + margin*2 + edge, margin + edge + base_y)
      context.set_source_rgb(0,0,0)
      hl_layout = header_left(message, context)
      if hl_layout
        context.show_pango_layout(hl_layout)
        hl_w, hl_h = hl_layout.pixel_size
        hr_layout = render_header_right(message, context, base_y, hl_w)
        if hr_layout
          [[hl_w, hr_layout.pixel_size[0]].max,
           [hl_h, hr_layout.pixel_size[1]].max]
        else
          [hl_w, hl_h] end end end end

  def render_header_right(message, context, base_y, header_left_width)
    header_w = width - icon_width - margin*3 - edge*2
    hr_layout = header_right(message, context)
    if hr_layout
      context.save do
        context.translate(header_w - hr_layout.pixel_size[0], 0)
        if header_left_width > header_w - hr_layout.pixel_size[0] - 20
          r, g, b = background_color(message)
          grad = Cairo::LinearPattern.new(-20, base_y, hr_layout.pixel_size[0] + 20, base_y)
          grad.add_color_stop_rgba(0.0, r, g, b, 0.0)
          grad.add_color_stop_rgba(20.0 / (hr_layout.pixel_size[0] + 20), r, g, b, 1.0)
          grad.add_color_stop_rgba(1.0, r, g, b, 1.0)
          context.rectangle(-20, 0, hr_layout.pixel_size[0] + 20, hr_layout.pixel_size[1])
          context.set_source(grad)
          context.fill() end
        context.show_pango_layout(hr_layout)
        hr_layout end end end

  def main_message(message, context = dummy_context)
    attr_list, text = Pango.parse_markup(Pango.escape(message.to_show))
    layout = context.create_pango_layout
    layout.width = (width - icon_width - margin*3 - edge*2) * Pango::SCALE
    layout.attributes = attr_list
    layout.wrap = Pango::WRAP_CHAR
    layout.font_description = default_font
    layout.text = text
    layout end

  def render_outline(message, context, base_y)
    render_outline_floating(message, context, base_y) end

  # エッジの描画。
  # 影にblurを入れて、浮いているような感じに
  def render_outline_floating(message, context, base_y, radius: 4, blur: 4)
    x,y,w,h = edge, edge + base_y, width - edge*2, message_height(message) - edge*2
    context.save {
      context.pseudo_blur(blur) {
        context.fill {
          context.set_source_rgb(*edge_color(message))
          context.rounded_rectangle(x,y,w,h, radius) } }
      context.fill {
        context.set_source_rgb(*background_color(message))
        context.rounded_rectangle(x,y,w,h, radius) } } end

  # エッジの描画。
  # 細い線を入れる
  def render_outline_solid(message, context, base_y, radius: 4)
    context.save {
      x,y,w,h = edge, edge + base_y, width - edge*2, message_height(message) - edge*2
      #context.fill {
        context.rounded_rectangle(x,y,w,h, radius)
        context.set_source_rgb(*background_color(message))
        context.fill_preserve
        context.set_line_width(border_weight)
        context.set_source_rgb(*edge_color(message))
        context.stroke } end

  # エッジの描画。
  # 枠線なし
  def render_outline_flat(message, context, base_y, radius: 4)
    context.save {
      x,y,w,h = edge, edge + base_y, width - edge*2, message_height(message) - edge*2
      context.fill {
        context.set_source_rgb(*background_color(message))
        context.rounded_rectangle(x,y,w,h, radius) } } end

  def render_badge(message, context)
    render_badge_floating(message, context) end

  # バッジの描画。
  # 影にblurを入れて、浮いているような感じに
  def render_badge_floating(message, context)
    badge_pixbuf = badge(message)
    if badge_pixbuf
      context.save {
        context.pseudo_blur(4) {
          context.fill {
            context.set_source_rgb(*edge_color(message))
            context.circle(0, 0, badge_radius) } }
        context.fill {
          context.set_source_rgb(*background_color(message))
          context.circle(0, 0, badge_radius) } }
      context.translate(-badge_radius, -badge_radius)
      context.set_source_pixbuf(badge_pixbuf)
      context.paint end end

  # バッジの描画。
  # 細い線を入れる
  def render_badge_solid(message, context)
    badge_pixbuf = badge(message)
    if badge_pixbuf
      context.save {
        context.circle(0, 0, badge_radius)
        context.set_source_rgb(*background_color(message))
        context.fill_preserve
        context.set_source_rgb(*edge_color(message))
        context.set_line_width(border_weight)
        context.stroke }
      context.translate(-badge_radius, -badge_radius)
      context.set_source_pixbuf(badge_pixbuf)
      context.paint end end

  # バッジの描画。
  # 枠線を入れない
  def render_badge_flat(message, context)
    badge_pixbuf = badge(message)
    if badge_pixbuf
      context.fill {
        context.set_source_rgb(*background_color(message))
        context.circle(0, 0, badge_radius) }
      context.translate(-badge_radius, -badge_radius)
      context.set_source_pixbuf(badge_pixbuf)
      context.paint end end

  def render_icon(message, context)
    if icon_size
      context.set_source_pixbuf(main_icon(message))
      context.paint end end

  def main_icon(message)
    message.user.icon.load_pixbuf(width: icon_size.width, height: icon_size.width){ helper.on_modify }
  end
end
