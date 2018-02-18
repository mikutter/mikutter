class Gdk::SubPartsWorldonVisibility < Gdk::SubParts
  register

  def get_photo(filename)
    return nil if filename.nil?
    path = Pathname(__dir__) / 'icon' / filename
    uri = Diva::URI.new('file://' + path.to_s)
    Plugin.filtering(:photo_filter, uri, [])[1].first
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
    photo = get_photo(filename(helper.message.visibility))
    photo&.pixbuf(width: @icon_size, height: @icon_size)
  end

  def show_icon?
    return false if (!UserConfig[:worldon_show_subparts_visibility] || !helper.message.respond_to?(:visibility))
    fn = filename(helper.message.visibility)
    !fn.nil?
  end

  def visibility_text(visibility)
    case visibility
    when 'unlisted'
      '未収載'
    when 'private'
      '非公開'
    when 'direct'
      'ダイレクト'
    else
      ''
    end
  end

  def initialize(*args)
    super

    @margin = 2
    @icon_size = 20
  end

  def render(context)
    if (helper.visible? && show_icon?)
      pixbuf = icon_pixbuf
      if pixbuf.nil?
        error "SubPartsWorldonVisibility: pixbuf.nil? detected! visibility = #{helper.message.visibility}"
        return
      end
      context.save do
        context.translate(@margin, @margin)
        context.set_source_pixbuf(pixbuf)
        context.paint

        context.translate(@icon_size + @margin, 0)
        context.set_source_rgb(*(UserConfig[:mumble_basic_color] || [0,0,0]).map{ |c| c.to_f / 65536 })
        layout = context.create_pango_layout
        layout.font_description = Pango::FontDescription.new(UserConfig[:mumble_basic_font])
        layout.text = visibility_text(helper.message.visibility)
        context.show_pango_layout(layout)
      end
    end
  end

  def height
    @height ||= show_icon? ? @icon_size + 2 * @margin : 0
  end
end

