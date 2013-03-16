# -*- coding: utf-8 -*-

require 'gtk2'
require 'cairo'

miquire :mui, 'coordinate_module'
miquire :mui, 'icon_over_button'
miquire :mui, 'textselector'
miquire :mui, 'sub_parts_helper'
miquire :mui, 'replyviewer'
miquire :mui, 'sub_parts_favorite'
miquire :mui, 'sub_parts_retweet'
miquire :mui, 'markup_generator'
miquire :lib, 'uithreadonly'

# 一つのMessageをPixbufにレンダリングするためのクラス。名前は言いたかっただけ。クラス名まで全てはつね色に染めて♪
# 情報を設定してから、 Gdk::MiraclePainter#pixbuf で表示用の Gdk::Pixbuf のインスタンスを得ることができる。
class Gdk::MiraclePainter < Gtk::Object

  type_register
  signal_new(:modified, GLib::Signal::RUN_FIRST, nil, nil)
  signal_new(:expose_event, GLib::Signal::RUN_FIRST, nil, nil)

  include Gdk::Coordinate
  include Gdk::IconOverButton
  include Gdk::TextSelector
  include Gdk::SubPartsHelper
  include Gdk::MarkupGenerator
  include UiThreadOnly

  EMPTY = Set.new.freeze
  Event = Struct.new(:event, :message, :timeline, :miraclepainter)
  WHITE = [65536, 65536, 65536].freeze
  BLACK = [0, 0, 0].freeze

  attr_reader :message, :p_message, :tree, :selected
  alias :to_message :message

  # @@miracle_painters = Hash.new

  # _message_ を内部に持っているGdk::MiraclePainterの集合をSetで返す。
  # ログ数によってはかなり重い処理なので注意
  def self.findbymessage(message)
    type_strict message => :to_message
    message = message.to_message
    result = Set.new
    Gtk::TimeLine.timelines.each{ |tl|
      found = tl.get_record_by_message(message)
      result << found.miracle_painter if found }
    result.freeze
  end

  # findbymessage のdeferred版。
  def self.findbymessage_d(message)
    type_strict message => :to_message
    message = message.to_message
    result = Set.new
    Gtk::TimeLine.timelines.deach{ |tl|
      if not tl.destroyed?
        found = tl.get_record_by_message(message)
        result << found.miracle_painter if found end
    }.next{
      result.freeze }
  end

  def self.mp_modifier
    @mp_modifier ||= lambda { |miracle_painter|
      if (not miracle_painter.destroyed?) and (not miracle_painter.tree.destroyed?)
        miracle_painter.tree.model.each{ |model, path, iter|
          if iter[0].to_i == miracle_painter.message[:id]
            miracle_painter.tree.queue_draw
            break end } end
      false } end

  def initialize(message, *coodinate)
    type_strict message => :to_message
    @p_message = message
    @message = message.to_message
    @selected = false
    @pixbuf = nil
    type_strict @message => Message
    super()
    coordinator(*coodinate)
    ssc(:modified, &Gdk::MiraclePainter.mp_modifier)
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
    return @pixbuf if @pixbuf
    if visible?
      @pixbuf = gen_pixbuf
      if(@pixbuf and defined?(@last_modify_height) and @last_modify_height != @pixbuf.height)
        tree.get_column(0).queue_resize
        @last_modify_height = @pixbuf.height end
      @pixbuf
    else
      @last_modify_height = height
      Gdk::WebImageLoader.loading_pixbuf(@last_modify_height, @last_modify_height) end
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
          l[:callback].call(l) if l and l[:callback] end end
    when 3
      @tree.get_ancestor(Gtk::Window).set_focus(@tree)
      Plugin::GUI::Command.menu_pop
    end end

  def on_selected
    if not frozen?
      @selected = true
      on_modify end end

  def on_unselected
    if not frozen?
      @selected = false
      on_modify end end

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
      [message.retweeted? ? "retweet.png" : nil,
       message.favorite? ? "unfav.png" : nil]
    ]
  end

  def iob_reply_clicked
    @tree.imaginary.create_reply_postbox(message) end

  def iob_retweet_clicked
    if message.retweeted?
      retweet = message.retweeted_statuses.find(&:from_me?)
      retweet.destroy if retweet
    else
      message.retweet
    end
    # @tree.imaginary.create_reply_postbox(message, :retweet => true)
  end

  def iob_fav_clicked
    message.favorite(!message.favorite?)
  end

  def iob_etc_clicked
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
    @modify_source = caller(1)
    if not destroyed?
      @pixmap = nil
      @pixbuf = nil
      @coordinate = nil
      signal_emit('modified') if event
    end
  end

  # 画面上にこれが表示されているかを返す
  def visible?
    if tree
      range = tree.visible_range
      if range and 2 == range.size
        Range.new(*range).cover?(tree.get_path_by_message(@message)) end end end

  def destroy
    def self.tree
      raise DestroyedError.new end
    def self.to_message
      raise DestroyedError.new end
    def self.p_message
      raise DestroyedError.new end

    instance_variables.each{ |v|
      instance_variable_set(v, nil) }

    @tree = nil
    signal_emit('destroy')
    super
    freeze
  end

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
    color = Plugin.filtering(:message_font_color, message, nil).last
    color = BLACK if not(color and color.is_a? Array and 3 == color.size)
    font = Plugin.filtering(:message_font, message, nil).last
    context.set_source_rgb(*color.map{ |c| c.to_f / 65536 })
    layout.font_description = Pango::FontDescription.new(font) if font
    layout.text = text
    layout end

  # ヘッダ（左）のための Pango::Layout のインスタンスを返す
  def header_left(context = dummy_context)
    attr_list, text = header_left_markup
    color = Plugin.filtering(:message_header_left_font_color, message, nil).last
    color = BLACK if not(color and color.is_a? Array and 3 == color.size)
    font = Plugin.filtering(:message_header_left_font, message, nil).last
    layout = context.create_pango_layout
    layout.attributes = attr_list
    context.set_source_rgb(*color.map{ |c| c.to_f / 65536 })
    layout.font_description = Pango::FontDescription.new(font) if font
    layout.text = text
    layout end

  def header_left_markup
    Pango.parse_markup("<b>#{Pango.escape(message[:user][:idname])}</b> #{Pango.escape(message[:user][:name] || '')}")
  end

  # ヘッダ（右）のための Pango::Layout のインスタンスを返す
  def header_right(context = dummy_context)
    hms = timestamp_label
    attr_list, text = Pango.parse_markup(hms)
    layout = context.create_pango_layout
    layout.attributes = attr_list
    font = Plugin.filtering(:message_header_right_font, message, nil).last
    layout.font_description = Pango::FontDescription.new(font) if font
    layout.text = text
    layout.alignment = Pango::ALIGN_RIGHT
    layout end

  def timestamp_label
    now = Time.now
    if message[:created].year == now.year && message[:created].month == now.month && message[:created].day == now.day
      Pango.escape(message[:created].strftime('%H:%M:%S'))
    else
      Pango.escape(message[:created].strftime('%Y/%m/%d %H:%M:%S'))
    end
  end

  # pixmapを組み立てる
  def gen_pixmap
    pm = Gdk::Pixmap.new(nil, width, height, color)
    render_to_context pm.create_cairo_context
    pm
  end

  # pixbufを組み立てる
  def gen_pixbuf
    @pixmap = gen_pixmap
    Gdk::Pixbuf.from_drawable(nil, @pixmap, 0, 0, width, height)
  end

  # アイコンのpixbufを返す
  def main_icon
    @main_icon ||= Gdk::WebImageLoader.pixbuf(message[:user][:profile_image_url], icon_width, icon_height){ |pixbuf|
      if not destroyed?
        @main_icon = pixbuf
        on_modify end } end

  # 背景色を返す
  def get_backgroundcolor
    color = Plugin.filtering(:message_background_color, self, nil).last
    if color.is_a? Array and 3 == color.size
      color.map{ |c| c.to_f / 65536 }
    else
      WHITE end end

  # Graphic Context にパーツを描画
  def render_to_context(context)
    render_background context
    render_main_icon context
    render_main_text context
    render_parts context end

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
      context.show_pango_layout(hl_layout)
      hr_layout = header_right(context)
      hr_color = Plugin.filtering(:message_header_right_font_color, message, nil).last
      hr_color = BLACK if not(hr_color and hr_color.is_a? Array and 3 == hr_color.size)

      hl_rectangle = Gdk::Rectangle.new(pos.header_text.x, pos.header_text.y,
                                        hl_layout.size[0] / Pango::SCALE, hl_layout.size[1] / Pango::SCALE)
      hr_rectangle = Gdk::Rectangle.new(pos.header_text.x + pos.header_text.w - (hr_layout.size[0] / Pango::SCALE), pos.header_text.y,
                                        hr_layout.size[0] / Pango::SCALE, hr_layout.size[1] / Pango::SCALE)
      @hl_region = Gdk::Region.new(hl_rectangle)
      @hr_region = Gdk::Region.new(hr_rectangle)

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
        context.set_source_rgb(*hr_color.map{ |c| c.to_f / 65536 })
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

