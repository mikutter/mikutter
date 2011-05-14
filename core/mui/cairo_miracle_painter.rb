# -*- coding: utf-8 -*-

require 'gtk2'
require 'cairo'

miquire :mui, 'coordinate_module'
miquire :mui, 'icon_over_button'

# 一つのMessageをPixbufにレンダリングするためのクラス。名前は言いたかっただけ。
# 情報を設定してから、 Gdk::MiraclePainter#pixbuf で表示用の Gdk::Pixbuf のインスタンスを得ることができる。
class Gdk::MiraclePainter < GLib::Object

  type_register
  signal_new(:modified, GLib::Signal::RUN_FIRST, nil, nil, self)

  include Gdk::Coordinate
  include Gdk::IconOverButton(:x_count => 2, :y_count => 2)

  attr_reader :message, :p_message, :tree

  @@miracle_painters = Hash.new(Set.new)

  def initialize(message, *coodinate)
    @tree = tree
    @p_message = message
    @message = message.to_message
    type_strict @message => Message
    super()
    coordinator(*coodinate)
    (@@miracle_painters[@message[:id].to_i] ||= WeakSet.new) << self end

  def set_tree(new)
    @tree = new
    self end

  # TLに表示するための Gdk::Pixmap のインスタンスを返す
  def pixmap
    @pixmap ||= gen_pixmap
  end

  # TLに表示するための Gdk::Pixbuf のインスタンスを返す
  def pixbuf
    @pixbuf ||= gen_pixbuf
  end

  # 座標 ( _x_ , _y_ ) にクリックイベントを発生させる
  def clicked(x, y)
    iob_clicked
    index = main_pos_to_index(x, y)
    if index
      links.each{ |l|
        match, range, regexp = *l
         if range.include?(index)
          Gtk::TimeLine.linkrules[regexp][0][match.to_s, nil] end } end end

  # 座標 ( _x_ , _y_ ) にマウスオーバーイベントを発生させる
  def point_moved(x, y)
    point_moved_main_icon(x, y)
  end

  # leaveイベントを発生させる
  def point_leaved(x, y)
    iob_main_leave
  end

  def iob_icon_pixbuf
    [ ["reply.png", "etc.png"],
      ["retweet.png",
       message.favorite? ? "unfav.png" : "fav.png"] ] end

  def iob_icon_pixbuf_off
    [ [(UserConfig[:show_replied_icon] and message.mentioned_by_me? and "reply.png"),
       nil],
      [nil,
       message.favorite? ? "unfav.png" : nil]
    ]
  end

  def iob_reply_clicked
    @tree.reply(message) end

  def iob_retweet_clicked
    @tree.reply(message, :retweet => true)
  end

  def iob_fav_clicked
    message.favorite(!message.favorite?)
  end

  def iob_etc_clicked
  end

  # つぶやきの左上座標から、クリックされた文字のインデックスを返す
  def main_pos_to_index(x, y)
    # x -= (icon_width + icon_margin * 2)
    # y -= (icon_margin + header_left(context).size[1] / Pango::SCALE)
    x -= pos.main_text.x
    y -= pos.main_text.y
    inside, byte, trailing = *main_message.xy_to_index(x * Pango::SCALE, y * Pango::SCALE)
    message.to_s.get_index_from_byte(byte) if inside end

  def signal_do_modified(this)
  end

  # 更新イベントを発生させる
  def on_modify(event=true)
    @pixmap = nil
    @pixbuf = nil
    @coordinate = nil
    signal_emit(:modified, self) if event
  end

  private

  def escaped_main_text
    message.to_show.gsub(/[<>&]/){|m| {'&' => '&amp;' ,'>' => '&gt;', '<' => '&lt;'}[$0] }.freeze end
  memoize :escaped_text

  def styled_main_text
    result = escaped_main_text.dup
    links.reverse_each{ |l|
      match, range, regexp = l
      splited = result.split(//u)
      splited[range] = '<span underline="single" underline_color="#000000">'+"#{match.to_s}</span>"
      result = splited.join('') }
    result end
  memoize :styled_main_text

  # [[MatchData, 開始位置と終了位置のRangeオブジェクト(文字数), Regexp], ...] の配列を返す
  def links
    result = Set.new
    Gtk::TimeLine.linkrules.keys.each{ |regexp|
      escaped_main_text.each_matches(regexp){ |match, pos|
        if not result.any?{ |this| this[1].include?(pos) }
          result << [match, Range.new(pos, pos + match.to_s.size, true), regexp] end } }
    result.sort_by{ |r| r[1].first }.freeze end
  memoize :links

  def dummy_context
    Gdk::Pixmap.new(nil, 1, 1, color).create_cairo_context end

  # 本文のための Pango::Layout のインスタンスを返す
  def main_message(context = dummy_context)
    attr_list, text = Pango.parse_markup(styled_main_text)
    layout = context.create_pango_layout
    layout.width = pos.main_text.width * Pango::SCALE
    layout.attributes = attr_list
    layout.wrap = Pango::WRAP_CHAR
    layout.font_description = Pango::FontDescription.new(UserConfig[:mumble_basic_font])
    layout.text = text
    layout end

  # ヘッダ（左）のための Pango::Layout のインスタンスを返す
  def header_left(context = dummy_context)
    attr_list, text = Pango.parse_markup("<b>#{message[:user][:idname]}</b> #{message[:user][:name]}")
    layout = context.create_pango_layout
    layout.attributes = attr_list
    layout.font_description = Pango::FontDescription.new(UserConfig[:mumble_basic_font])
    layout.text = text
    layout end

  # ヘッダ（右）のための Pango::Layout のインスタンスを返す
  def header_right(context = dummy_context)
    attr_list, text = Pango.parse_markup("<span foreground=\"#999999\">#{message[:created].strftime('%H:%M:%S')}</span>")
    layout = context.create_pango_layout
    layout.attributes = attr_list
    layout.font_description = Pango::FontDescription.new(UserConfig[:mumble_basic_font])
    layout.text = text
    layout.width = pos.main_text.width * Pango::SCALE
    layout.alignment = Pango::ALIGN_RIGHT
    layout end

  # pixbufを組み立てる
  def gen_pixmap
    pm = Gdk::Pixmap.new(nil, width, height, color)
    render_to_context pm.create_cairo_context
    pm end

  # pixbufを組み立てる
  def gen_pixbuf
    Gdk::Pixbuf.from_drawable(Gdk::Colormap.system, pixmap, 0, 0, width, height)
  end

  # アイコンのpixbufを返す
  def main_icon
    @main_icon ||= Gtk::WebIcon.get_icon_pixbuf(message[:user][:profile_image_url], icon_width, icon_height){ |pixbuf|
      @main_icon = pixbuf
      on_modify } end

  # Graphic Context にパーツを描画
  def render_to_context(context)
    render_background context
    render_main_icon context
    render_main_text context
  end

  def render_background(context)
    context.save{
      context.set_source_rgb(1,1,1)
      context.rectangle(0,0,width,height)
      context.fill
    }
  end

  def render_main_icon(context)
    context.save{
      context.translate(pos.main_icon.x, pos.main_icon.x)
      context.set_source_pixbuf(main_icon)
      context.paint
      render_icon_over_button(context)
    }
  end

  def render_main_text(context)
    context.save{
      context.translate(pos.header_text.x, pos.header_text.y)
      context.set_source_rgb(0,0,0)
      hl_layout = header_left(context)
      context.show_pango_layout(hl_layout)
      context.show_pango_layout(header_right(context))
    }
    context.save{
      context.translate(pos.main_text.x, pos.main_text.y)
      context.show_pango_layout(main_message(context))
    }
  end

  Plugin.create(:core).add_event(:posted){ |service, messages|
    messages.each{ |message|
      if(replyto_source = message.replyto_source)
        @@miracle_painters[replyto_source[:id].to_i].each{ |mp|
          mp.on_modify } end } }

  Plugin.create(:core).add_event(:favorite){ |service, user, message|
    if(user.is_me?)
      @@miracle_painters[message[:id].to_i].each{ |mp|
        mp.on_modify } end }

end
# ~> -:6: undefined method `miquire' for main:Object (NoMethodError)
