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
miquire :mui, 'pseudo_signal_handler'
miquire :mui, 'markup_generator'

# 一つのMessageをPixbufにレンダリングするためのクラス。名前は言いたかっただけ。クラス名まで全てはつね色に染めて♪
# 情報を設定してから、 Gdk::MiraclePainter#pixbuf で表示用の Gdk::Pixbuf のインスタンスを得ることができる。
class Gdk::MiraclePainter < GLib::Object

  type_register
  signal_new(:modified, GLib::Signal::RUN_FIRST, nil, nil)
  signal_new(:expose_event, GLib::Signal::RUN_FIRST, nil, nil)

  include Gdk::Coordinate
  include Gdk::IconOverButton(:x_count => 2, :y_count => 2)
  include Gdk::TextSelector
  include Gdk::SubPartsHelper(Gdk::ReplyViewer, Gdk::SubPartsFavorite, Gdk::SubPartsRetweet)
  include PseudoSignalHandler
  include Gdk::MarkupGenerator

  EMPTY = Set.new.freeze
  Event = Struct.new(:event, :message, :timeline, :miraclepainter)

  attr_reader :message, :p_message, :tree
  alias :to_message :message

  # @@miracle_painters = Hash.new

  # _message_ を内部に持っているGdk::MiraclePainterの集合をSetで返す
  def self.findbymessage(message)
    type_strict message => :to_message
    message = message.to_message
    result = Set.new
    Gtk::TimeLine.timelines.each{ |tl|
      found = tl.get_record_by_message(message)
      result << found.miracle_painter if found }
    result.freeze
    # @@miracle_painters[message.to_message[:id].to_i] || EMPTY
  end

  def initialize(message, *coodinate)
    type_strict message => :to_message
    @p_message = message
    @message = message.to_message
    type_strict @message => Message
    super()
    coordinator(*coodinate)
    # (@@miracle_painters[@message[:id].to_i] ||= WeakSet.new(Gdk::MiraclePainter)) << self
  end

  signal_new(:click, GLib::Signal::RUN_FIRST, nil, nil,
             Gdk::EventButton, Integer, Integer)

  signal_new(:motion_notify_event, GLib::Signal::RUN_FIRST, nil, nil,
             Integer, Integer)

  signal_new(:leave_notify_event, GLib::Signal::RUN_FIRST, nil, nil)

  def signal_do_click(event, cell_x, cell_y)
  end

  def signal_do_motion_notify_event(cell_x, cell_y)
  end

  def signal_do_leave_notify_event()
  end

  # Gtk::TimeLine::InnerTLのインスタンスを設定する。今後、このインスタンスは _new_ に所属するものとして振舞う
  def set_tree(new)
    type_strict new => Gtk::TimeLine::InnerTL
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

  # MiraclePainterの座標x, y上でポインティングデバイスのボタン1が押されたことを通知する
  def pressed(x, y)
    textselector_press(*main_pos_to_index_forclick(x, y)[1..2])
  end

  # MiraclePainterの座標x, y上でポインティングデバイスのボタン1が離されたことを通知する
  def released(x=nil, y=nil)
    if(x == y and not x)
      unselect
    else
      textselector_release(*main_pos_to_index_forclick(x, y)[1..2]) end end

  # 座標 ( _x_ , _y_ ) にクリックイベントを発生させる
  def clicked(x, y, e)
    signal_emit(:click, e, x, y)
    case e.button
    when 1
      iob_clicked
      if not textselector_range
        index = main_pos_to_index(x, y)
        if index
          l = message.links.segment_by_index(index)
          l[:callback].call(l) if l end end
    when 3
      menu_pop(e)
    end
  end

  # 座標 ( _x_ , _y_ ) にマウスオーバーイベントを発生させる
  def point_moved(x, y)
    point_moved_main_icon(x, y)
    signal_emit(:motion_notify_event, x, y)
    textselector_select(*main_pos_to_index_forclick(x, y)[1..2]) end

  # leaveイベントを発生させる
  def point_leaved(x, y)
    iob_main_leave
    signal_emit(:leave_notify_event)
    # textselector_release
  end

  # MiraclePainterが選択解除されたことを通知する
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
    tl, active_mumble, miracle_painter, postbox, valid_roles = Addon::Command.tampr(:message => message, :miracle_painter => self)
    labels = []
    contextmenu = []
    Plugin.filtering(:command, Hash.new).first.values.each{ |record|
      if(record[:visible] and valid_roles.include?(record[:role]))
        index = where_should_insert_it(record[:slug].to_s, labels, UserConfig[:mumble_contextmenu_order] || [])
        labels.insert(index, record[:slug].to_s)
        contextmenu.insert(index, [record[:show_face] || record[:name], lambda{ |x| record[:condition] === x }, record[:exec]]) end }
    Gtk::ContextMenu.new(*contextmenu).popup(tl,
                                             Event.new(event, active_mumble, tl, miracle_painter))
  end

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

  def signal_do_modified()
  end

  def signal_do_expose_event()
  end

  # 更新イベントを発生させる
  def on_modify(event=true)
    if not destroyed?
      @pixmap = nil
      @pixbuf = nil
      @coordinate = nil
      if(defined? @last_modify_height and @last_modify_height != height)
        tree.get_column(0).queue_resize
        @last_modify_height = height end
      signal_emit('modified') if event
    end
  end

  # 画面上にこれが表示されているかを返す
  def visible?
    if tree
      start, last = tree.visible_range
      if start
        range = tree.selected_range_bytime
        if(tree.vadjustment.value == 0)
          range.first <= message.modified.to_i
        else
          range.include?(message.modified.to_i) end end
    else
      true end end

  def destroy
    def self.destroyed?
      true end
    def self.tree
      raise DestroyedError.new end
    def self.to_message
      raise DestroyedError.new end
    def self.p_message
      raise DestroyedError.new end

    instance_variables.each{ |v|
      instance_variable_set(v, nil) }

    @tree = nil
    freeze
  end

  def destroyed?
    false end

  private

  def dummy_context
    Gdk::Pixmap.new(nil, 1, 1, color).create_cairo_context end

  # 本文のための Pango::Layout のインスタンスを返す
  def main_message(context = dummy_context)
    begin
      attr_list, text = Pango.parse_markup(textselector_markup(styled_main_text))
    rescue GLib::Error => e
      attr_list, text = nil, Pango.escape(message.to_show)
    end
    layout = context.create_pango_layout
    layout.width = pos.main_text.width * Pango::SCALE
    layout.attributes = attr_list if attr_list
    layout.wrap = Pango::WRAP_CHAR
    context.set_source_rgb(*(UserConfig[:mumble_basic_color] || [0,0,0]).map{ |c| c.to_f / 65536 })
    layout.font_description = Pango::FontDescription.new(UserConfig[:mumble_basic_font])
    layout.text = text
    layout end

  # ヘッダ（左）のための Pango::Layout のインスタンスを返す
  def header_left(context = dummy_context)
    attr_list, text = Pango.parse_markup("<b>#{Pango.escape(message[:user][:idname])}</b> #{Pango.escape(message[:user][:name] || '')}")
    layout = context.create_pango_layout
    layout.attributes = attr_list
    layout.font_description = Pango::FontDescription.new(UserConfig[:mumble_basic_font])
    layout.text = text
    layout end

  # ヘッダ（右）のための Pango::Layout のインスタンスを返す
  def header_right(context = dummy_context)
    now = Time.now
    hms = if message[:created].year == now.year && message[:created].month == now.month && message[:created].day == now.day
            message[:created].strftime('%H:%M:%S')
          else
            message[:created].strftime('%Y/%m/%d %H:%M:%S')
          end
    attr_list, text = Pango.parse_markup("<span foreground=\"#999999\">#{Pango.escape(hms)}</span>")
    layout = context.create_pango_layout
    layout.attributes = attr_list
    layout.font_description = Pango::FontDescription.new(UserConfig[:mumble_basic_font])
    layout.text = text
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
    Gdk::Pixbuf.from_drawable(@colormap ||= Gdk::Colormap.system, @pixmap, 0, 0, width, height)
  end

  # アイコンのpixbufを返す
  def main_icon
    @main_icon ||= Gtk::WebIcon.get_icon_pixbuf(message[:user][:profile_image_url], icon_width, icon_height){ |pixbuf|
      if not destroyed?
        @main_icon = pixbuf
        on_modify end } end

  # 背景色を返す
  def get_backgroundcolor
    color = if(message.from_me?)
              UserConfig[:mumble_self_bg]
            elsif(message.to_me?)
              UserConfig[:mumble_reply_bg]
            else
              UserConfig[:mumble_basic_bg] end
    color.map{ |c| c.to_f / 65536 } end

  # Graphic Context にパーツを描画
  def render_to_context(context)
    render_background context
    render_main_icon context
    render_main_text context
    render_parts context
  end

  def render_background(context)
    context.save{
      context.set_source_rgb(*get_backgroundcolor)
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
      hr_layout = header_right(context)
      context.show_pango_layout(hl_layout)

      context.save{
        context.translate(pos.header_text.w - (hr_layout.size[0] / Pango::SCALE), 0)
        if (hl_layout.size[0] / Pango::SCALE) > (pos.header_text.w - (hr_layout.size[0] / Pango::SCALE) - 20)
          r, g, b = get_backgroundcolor
          grad = Cairo::LinearPattern.new(-20, 0, hr_layout.size[0] / Pango::SCALE + 20, 0)
          grad.add_color_stop_rgba(0.0, r, g, b, 0.0)
          grad.add_color_stop_rgba(20.0 / (hr_layout.size[0] / Pango::SCALE + 20), r, g, b, 1.0)
          grad.add_color_stop_rgba(1.0, r, g, b, 1.0)
          context.rectangle(-20, 0, hr_layout.size[0] / Pango::SCALE + 20, hr_layout.size[1] / Pango::SCALE)
          context.set_source(grad)
          context.fill() end

        context.show_pango_layout(hr_layout) } }
    context.save{
      context.translate(pos.main_text.x, pos.main_text.y)
      context.show_pango_layout(main_message(context)) } end

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

  }

  class DestroyedError < Exception
  end

end

module Pango
  ESCAPE_RULE = {'&' => '&amp;' ,'>' => '&gt;', '<' => '&lt;'}.freeze
  class << self

    # テキストをPango.parse_markupで安全にパースできるようにエスケープする。
    def escape(text)
      text.gsub(/[<>&]/){|m| Pango::ESCAPE_RULE[m] } end

    alias old_parse_markup parse_markup

    # パースエラーが発生した場合、その文字列をerrorで印字する。
    def parse_markup(str)
      begin
        old_parse_markup(str)
      rescue GLib::Error => e
        error str
        raise e end end end end
# ~> -:6: undefined method `miquire' for main:Object (NoMethodError)
