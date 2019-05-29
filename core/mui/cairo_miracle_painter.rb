# -*- coding: utf-8 -*-

require 'gtk2'
require 'cairo'

miquire :mui, 'coordinate_module'
miquire :mui, 'icon_over_button'
miquire :mui, 'textselector'
miquire :mui, 'sub_parts_helper'
miquire :mui, 'replyviewer'
miquire :mui, 'sub_parts_favorite'
miquire :mui, 'sub_parts_share'
miquire :mui, 'sub_parts_quote'
miquire :mui, 'markup_generator'
miquire :mui, 'special_edge'
miquire :mui, 'photo_pixbuf'
miquire :lib, 'uithreadonly'

# 一つのMessageをPixbufにレンダリングするためのクラス。名前は言いたかっただけ。クラス名まで全てはつね色に染めて♪
# 情報を設定してから、 Gdk::MiraclePainter#pixbuf で表示用の GdkPixbuf::Pixbuf のインスタンスを得ることができる。
class Gdk::MiraclePainter < Gtk::Object
  extend Gem::Deprecate

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
  WHITE = ([0xffff]*3).freeze
  BLACK = [0, 0, 0].freeze

  attr_reader :message, :p_message, :tree, :selected

  # :nodoc:
  def to_message
    message end
  deprecate :to_message, :none, 2017, 5

  # :nodoc:
  memoize def score
    Plugin[:gtk].score_of(message)
  end

  # @@miracle_painters = Hash.new

  # _message_ を内部に持っているGdk::MiraclePainterの集合をSetで返す。
  # ログ数によってはかなり重い処理なので注意
  def self.findbymessage(message)
    result = Set.new
    Gtk::TimeLine.timelines.each{ |tl|
      found = tl.get_record_by_message(message)
      result << found.miracle_painter if found }
    result.freeze
  end

  # findbymessage のdeferred版。
  def self.findbymessage_d(message)
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
          if iter[0] == miracle_painter.message.uri.to_s
            miracle_painter.tree.queue_draw
            break end } end
      false } end

  def initialize(message, *coodinate)
    @p_message = message
    @message = message
    @selected = false
    @pixbuf = nil
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

  # TLに表示するための GdkPixbuf::Pixbuf のインスタンスを返す
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
      Skin[:loading].pixbuf(width: @last_modify_height, height: @last_modify_height)
    end
  end

  # MiraclePainterの座標x, y上でポインティングデバイスのボタン1が押されたことを通知する
  def pressed(x, y)
    textselector_press(*main_pos_to_index_forclick(x, y)[1..2])
  end

  # MiraclePainterの座標x, y上でポインティングデバイスのボタン1が離されたことを通知する
  def released(x=nil, y=nil)
    if not destroyed?
      if(x == y and not x)
        unselect
      else
        textselector_release(*main_pos_to_index_forclick(x, y)[1..2]) end end end

  # 座標 ( _x_ , _y_ ) にクリックイベントを発生させる
  def clicked(x, y, event)
    signal_emit(:click, event, x, y)
    case event.button
    when 1
      iob_clicked(x, y)
      if not textselector_range
        index = main_pos_to_index(x, y)
        if index
          clicked_note = score.find{|note|
            index -= note.description.size
            index <= 0
          }
          Plugin.call(:open, clicked_note) if clickable?(clicked_note)
        end
      end
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
    textselector_select(*main_pos_to_index_forclick(x, y)[1..2])

    # change cursor shape
    set_cursor(cursor_name_of(x, y))
  end

  # leaveイベントを発生させる
  def point_leaved(x, y)
    iob_main_leave
    signal_emit(:leave_notify_event)
    # textselector_release

    # restore cursor shape
    set_cursor('default')
  end

  # このMiraclePainterの(x , y)にマウスポインタがある時に表示すべきカーソルの名前を返す。
  # ==== Args
  # [x] x座標(Integer)
  # [y] y座標(Integer)
  # ==== Return
  # [String] カーソルの名前
  private def cursor_name_of(x, y)
    index = main_pos_to_index(x, y)
    if index # the cursor is placed on text
      pointed_note = score.find{|note|
        index -= note.description.size
        index <= 0
      }
      if clickable?(pointed_note)
        # the cursor is placed on link
        'pointer'
      else
        'text'
      end
    else
      'default'
    end
  end

  # _name_ に対応するマウスカーソルに変更する。
  # ==== Args
  # [name] カーソルの名前(String)
  private def set_cursor(name)
    window = @tree.get_ancestor Gtk::Window
    type =
      case name
      when 'pointer'
        Gdk::Cursor::HAND2
      when 'text'
        Gdk::Cursor::XTERM
      else
        Gdk::Cursor::LEFT_PTR
      end
    window.window.cursor = Gdk::Cursor.new(type)
    self
  end

  # MiraclePainterが選択解除されたことを通知する
  def unselect
    textselector_unselect end

  def iob_icon_pixbuf
    [ ["reply.png".freeze, message.user.verified? ? "verified.png" : "etc.png"],
      [if message.user.protected? then "protected.png".freeze else "retweet.png".freeze end,
       message.favorite? ? "unfav.png".freeze : "fav.png".freeze] ] end

  def iob_icon_pixbuf_off
    world, = Plugin.filtering(:world_current, nil)
    [ [(UserConfig[:show_replied_icon] and message.mentioned_by_me? and "reply.png".freeze),
       UserConfig[:show_verified_icon] && message.user.verified? && "verified.png"],
      [ if UserConfig[:show_protected_icon] and message.user.protected?
          "protected.png".freeze
        elsif Plugin[:miracle_painter].shared?(message, world)
          "retweet.png".freeze end,
       message.favorite? ? "unfav.png".freeze : nil]
    ]
  end

  def iob_reply_clicked
    @tree.imaginary.create_reply_postbox(message) end

  def iob_retweet_clicked
    world, = Plugin.filtering(:world_current, nil)
    if Plugin[:miracle_painter].shared?(message, world)
      retweet = message.retweeted_statuses.find(&:from_me?)
      retweet.destroy if retweet
    else
      Plugin[:miracle_painter].share(message, world)
    end
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
    main_message.text.get_index_from_byte(byte) if inside end

  def main_pos_to_index_forclick(x, y)
    x -= pos.main_text.x
    y -= pos.main_text.y
    result = main_message.xy_to_index(x * Pango::SCALE, y * Pango::SCALE)
    result[1] = main_message.text.get_index_from_byte(result[1])
    return *result end

  def signal_do_modified()
  end

  def signal_do_expose_event()
  end

  # 更新イベントを発生させる
  def on_modify(event=true)
    if not destroyed?
      @modify_source = caller(1)
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
    def self.message
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
    layout = context.create_pango_layout
    font = Plugin.filtering(:message_font, message, nil).last
    layout.font_description = font_description(font) if font
    layout.width = pos.main_text.width * Pango::SCALE
    layout.attributes = textselector_attr_list(description_attr_list(emoji_height: emoji_height(layout.font_description)))
    layout.wrap = Pango::WrapMode::CHAR
    color = Plugin.filtering(:message_font_color, message, nil).last
    color = BLACK if not(color and color.is_a? Array and 3 == color.size)
    context.set_source_rgb(*color.map{ |c| c.to_f / 65536 })
    layout.text = plain_description
    layout.context.set_shape_renderer do |c, shape, _|
      photo = shape.data
      if photo
        width, height = shape.ink_rect.width/Pango::SCALE, shape.ink_rect.height/Pango::SCALE
        pixbuf = photo.load_pixbuf(width: width, height: height){ on_modify }
        x = layout.index_to_pos(shape.start_index).x / Pango::SCALE
        y = layout.index_to_pos(shape.start_index).y / Pango::SCALE
        c.translate(x, y)
        c.set_source_pixbuf(pixbuf)
        c.rectangle(0, 0, width, height)
        c.fill
      end
    end
    layout end

  @@font_description = Hash.new{|h,k| h[k] = {} } # {scale => {font => FontDescription}}
  def font_description(font)
    @@font_description[scale(0xffff)][font] ||=
      Pango::FontDescription.new(font).tap{|fd| fd.size = scale(fd.size) }
  end

  # 絵文字を描画する時の一辺の大きさを返す
  # ==== Args
  # [font] font description
  # ==== Return
  # [Integer] 高さ(px)
  memoize def emoji_height(font)
    layout = dummy_context.create_pango_layout
    layout.font_description = font
    layout.text = '.'
    layout.pixel_size[1]
  end

  # ヘッダ（左）のための Pango::Layout のインスタンスを返す
  def header_left(context = dummy_context)
    attr_list, text = header_left_markup
    color = Plugin.filtering(:message_header_left_font_color, message, nil).last
    color = BLACK if not(color and color.is_a? Array and 3 == color.size)
    font = Plugin.filtering(:message_header_left_font, message, nil).last
    layout = context.create_pango_layout
    layout.attributes = attr_list
    context.set_source_rgb(*color.map{ |c| c.to_f / 65536 })
    layout.font_description = font_description(font) if font
    layout.text = text
    layout end

  def header_left_markup
    user = message.user
    if user.respond_to?(:idname)
      Pango.parse_markup("<b>#{Pango.escape(user.idname)}</b> #{Pango.escape(user.name || '')}")
    else
      Pango.parse_markup(Pango.escape(user.name || ''))
    end
  end

  # ヘッダ（右）のための Pango::Layout のインスタンスを返す
  def header_right(context = dummy_context)
    hms = timestamp_label
    attr_list, text = Pango.parse_markup(hms)
    layout = context.create_pango_layout
    layout.attributes = attr_list
    font = Plugin.filtering(:message_header_right_font, message, nil).last
    layout.font_description = font_description(font) if font
    layout.text = text
    layout.alignment = Pango::Alignment::RIGHT
    layout end

  def timestamp_label
    now = Time.now
    if message.created.year == now.year && message.created.month == now.month && message.created.day == now.day
      Pango.escape(message.created.strftime('%H:%M:%S'))
    else
      Pango.escape(message.created.strftime('%Y/%m/%d %H:%M:%S'))
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
    src_width, src_height = @pixmap.size
    GdkPixbuf::Pixbuf.from_drawable(nil, @pixmap, 0, 0, src_width, src_height)
  end

  # アイコンのpixbufを返す
  def main_icon
    @main_icon ||= message.user.icon.load_pixbuf(width: icon_width, height: icon_height){|pixbuf|
      @main_icon = pixbuf
      on_modify
    }
  end

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
    context.save do
      context.set_source_rgb(*get_backgroundcolor)
      context.rectangle(0,0,width,height)
      context.fill
      if Gtk.konami
        context.save do
          context.translate(width - 48, height - 54)
          context.set_source_pixbuf(Gtk.konami_image)
          context.paint end end end end

  def render_main_icon(context)
    case Plugin.filtering(:main_icon_form, :square)[0]
    when :aspectframe
      render_main_icon_aspectframe(context)
    else
      render_main_icon_square(context)
    end
  end

  def render_main_icon_square(context)
    context.save{
      context.translate(pos.main_icon.x, pos.main_icon.y)
      context.set_source_pixbuf(main_icon)
      context.paint
    }
    if not (message.system?)
      render_icon_over_button(context) end
  end

  def render_main_icon_aspectframe(context)
    context.save do
      context.save do
        context.translate(pos.main_icon.x, pos.main_icon.y + icon_height*13/14)
        context.set_source_pixbuf(gb_foot.load_pixbuf(width: icon_width, height: icon_width*9/20){|_pb, _s| on_modify })
        context.paint
      end
      context.translate(pos.main_icon.x, pos.main_icon.y)
      context.append_path(Cairo::SpecialEdge.path(icon_width, icon_height))
      context.set_source_rgb(0,0,0)
      context.stroke
      context.append_path(Cairo::SpecialEdge.path(icon_width, icon_height))
      context.set_source_pixbuf(main_icon)
      context.fill
    end
    if not (message.system?)
      render_icon_over_button(context) end
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

  def gb_foot
    self.class.gb_foot
  end

  class << self
    extend Memoist

    memoize def gb_foot
      Enumerator.new{|y|
        Plugin.filtering(:photo_filter, Cairo::SpecialEdge::FOOTER_URL, y)
      }.first
    end
  end

  class DestroyedError < Exception
  end

end
