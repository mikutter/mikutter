class Gdk::SubPartsWorldonVisibility < Gdk::SubParts
  register

  def get_photo(filename)
    return nil if filename.nil?
    path = Pathname(__dir__) / 'icon' / filename
    Plugin.filtering(:photo_filter, path.to_s, [])[1].first
  end

  def filename(visibility)
    # アイコン素材取得元→ http://icooon-mono.com/license/
    case visibility
    when 'unlisted'
      'unlisted.png'
    when 'private'
      'private.png'
    when 'direct'
      'direct.png'
    else
      nil
    end
  end

  def icon_pixbuf
    return nil if !helper.message.respond_to?(:visibility)
    get_photo(filename(helper.message.visibility))&.pixbuf(width: 20, height: 20)
  end

  def show_icon?
    return nil if !helper.message.respond_to?(:visibility)
    fn = filename(helper.message)
    !fn.nil?
  end

  def initialize(*args)
    super

    @margin = 2
  end

  def render(context)
    # テキスト描画
    #if helper.visible? && helper.message.respond_to?(:visibility) && helper.message.visibility != 'public'
    #  context.save do
    #    context.translate(@margin, 0)
    #    layout = context.create_pango_layout.tap do |layout|
    #      layout.font_description = Pango::FontDescription.new(UserConfig[:mumble_basic_font])
    #      layout.text = helper.message.visibility
    #    end
    #    context.set_source_rgb(*(UserConfig[:mumble_basic_color] || [0,0,0]).map{ |c| c.to_f / 65536 })
    #    context.show_pango_layout(layout)
    #  end
    #end

    # 画像描画
    if (helper.visible? && show_icon?)
      pixbuf = icon_pixbuf
      if pixbuf
        context.save do
          context.translate(@margin, 0)
          context.scale
          context.set_source_pixbuf(pixbuf)
          context.paint
        end
      end
    end
  end

  def height
    @height ||= show_icon? ? 20 : 0
  end
end

