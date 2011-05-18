# -*- coding: utf-8 -*-

require 'gtk2'
require 'cairo'

miquire :mui, 'coordinate_module'
miquire :mui, 'icon_over_button'
miquire :mui, 'textselector'
miquire :mui, 'replyviewer'
miquire :mui, 'sub_parts_helper'
miquire :mui, 'sub_parts_favorite'
miquire :mui, 'sub_parts_retweet'

# 一つのMessageをPixbufにレンダリングするためのクラス。名前は言いたかっただけ。
# 情報を設定してから、 Gdk::MiraclePainter#pixbuf で表示用の Gdk::Pixbuf のインスタンスを得ることができる。
class Gdk::MiraclePainter < GLib::Object

  type_register
  signal_new(:modified, GLib::Signal::RUN_FIRST, nil, nil, self)
  signal_new(:expose_event, GLib::Signal::RUN_FIRST, nil, nil)

  include Gdk::Coordinate
  include Gdk::IconOverButton(:x_count => 2, :y_count => 2)
  include Gdk::TextSelector
  include Gdk::SubPartsHelper(Gdk::ReplyViewer, Gdk::SubPartsFavorite, Gdk::SubPartsRetweet)

  EMPTY = Set.new.freeze
  Event = Struct.new(:event, :message, :timeline, :miraclepainter)

  attr_reader :message, :p_message, :tree
  alias :to_message :message

  @@miracle_painters = Hash.new

  def self.findbymessage(message)
    type_strict message => :to_message
    @@miracle_painters[message.to_message[:id].to_i] || EMPTY
  end

  def initialize(message, *coodinate)
    type_strict message => :to_message
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

  def pressed(x, y)
    textselector_press(*main_pos_to_index_forclick(x, y)[1..2])
  end

  def released(x=nil, y=nil)
    if(x == y and not x)
      unselect
    else
      textselector_release(*main_pos_to_index_forclick(x, y)[1..2]) end end

  # 座標 ( _x_ , _y_ ) にクリックイベントを発生させる
  def clicked(x, y, e)
    case e.button
    when 1
      iob_clicked
      if not textselector_range
        index = main_pos_to_index(x, y)
        if index
          links.each{ |l|
            match, range, regexp = *l
            if range.include?(index)
              Gtk::TimeLine.linkrules[regexp][0][match.to_s, nil] end } end end
    when 3
      menu_pop(e)
    end
  end

  # 座標 ( _x_ , _y_ ) にマウスオーバーイベントを発生させる
  def point_moved(x, y)
    point_moved_main_icon(x, y)
    textselector_select(*main_pos_to_index_forclick(x, y)[1..2]) end

  # leaveイベントを発生させる
  def point_leaved(x, y)
    iob_main_leave
    # textselector_release
  end

  def unselect
    textselector_unselect end

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

  def menu_pop(event)
    menu = []
    filter = if textselector_range
               :contextmenu_text_selected
             else
               :contextmenu end
    Plugin.filtering(filter, []).first.each{ |x|
      cur = x.first
      cur = cur.call(nil, nil) if cur.respond_to?(:call)
      index = where_should_insert_it(cur, menu, UserConfig[:mumble_contextmenu_order] || [])
      menu[index] = x }
    Gtk::ContextMenu.new(*menu).popup(Gtk::TimeLine::InnerTL.current_tl,
                                      Event.new(event, message, Gtk::TimeLine::InnerTL.current_tl, self)) end

  # つぶやきの左上座標から、クリックされた文字のインデックスを返す
  def main_pos_to_index(x, y)
    x -= pos.main_text.x
    y -= pos.main_text.y
    inside, byte, trailing = *main_message.xy_to_index(x * Pango::SCALE, y * Pango::SCALE)
    message.to_s.get_index_from_byte(byte) if inside end

  def main_pos_to_index_forclick(x, y)
    x -= pos.main_text.x
    y -= pos.main_text.y
    result = main_message.xy_to_index(x * Pango::SCALE, y * Pango::SCALE)
    result[1] = message.to_s.get_index_from_byte(result[1])
    return *result end

  def signal_do_modified(this)
  end

  def signal_do_expose_event()
  end

  # 更新イベントを発生させる
  def on_modify(event=true)
    @pixmap = nil
    @pixbuf = nil
    @coordinate = nil
    if(defined? @last_modify_height and @last_modify_height != height)
      tree.get_column(0).queue_resize
      @last_modify_height = height end
    signal_emit(:modified, self) if event
  end

  # 画面上にこれが表示されているかを返す
  def visible?
    if tree
      start, last = tree.visible_range
      if start
        range = Range.new(*[tree.model.get_iter(last)[2], tree.model.get_iter(start)[2]].sort)
        if(tree.vadjustment.value == 0)
          range.first <= message.modified.to_i
        else
          range.include?(message.modified.to_i) end end
    else
      true end end

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
          pos = escaped_main_text[0, pos].strsize
          result << [match, Range.new(pos, pos + match.to_s.strsize, true), regexp] end } }
    result.sort_by{ |r| r[1].first }.freeze end
  memoize :links

  def dummy_context
    Gdk::Pixmap.new(nil, 1, 1, color).create_cairo_context end

  # 本文のための Pango::Layout のインスタンスを返す
  def main_message(context = dummy_context)
    attr_list, text = Pango.parse_markup(textselector_markup(styled_main_text))
    layout = context.create_pango_layout
    layout.width = pos.main_text.width * Pango::SCALE
    layout.attributes = attr_list
    layout.wrap = Pango::WRAP_CHAR
    context.set_source_rgb(*(UserConfig[:mumble_basic_color] || [0,0,0]).map{ |c| c.to_f / 65536 })
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

  # pixmapを組み立てる
  def gen_pixmap
    pm = Gdk::Pixmap.new(nil, width, height, color)
    render_to_context pm.create_cairo_context
    pm
  end

  # pixbufを組み立てる
  def gen_pixbuf
    @pixmap = gen_pixmap
    Gdk::Pixbuf.from_drawable(Gdk::Colormap.system, @pixmap, 0, 0, width, height)
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
    render_parts context
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
    }
    render_icon_over_button(context)
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

  Delayer.new{
    Plugin.create(:core).add_event(:posted){ |service, messages|
      messages.each{ |message|
        if(replyto_source = message.replyto_source)
          findbymessage(replyto_source).each{ |mp|
            mp.on_modify } end } }

    Plugin.create(:core).add_event(:favorite){ |service, user, message|
      if(user.is_me?)
        findbymessage(message).each{ |mp|
          mp.on_modify } end }

    Plugin.create(:core).add_event_filter(:contextmenu_text_selected){ |menu|
      menu << ['コピー',
               lambda{ |opt| true },
               lambda{ |opt|
                 Gtk::Clipboard.copy(opt.message.to_s.split(//u)[opt.miraclepainter.textselector_range].join) } ]
      [menu]
    }
  }

end
# ~> -:6: undefined method `miquire' for main:Object (NoMethodError)
