class Gdk::SubPartsWorldonStatusInfo < Gdk::SubParts
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
    return true if (UserConfig[:worldon_show_subparts_bot] && helper.message.user.respond_to?(:bot) && helper.message.user.bot)
    return true if (UserConfig[:worldon_show_subparts_visibility] && helper.message.respond_to?(:visibility) && filename(helper.message.visibility))
    false
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
    if helper.visible? && show_icon?
      if helper.message.user.respond_to?(:bot) && helper.message.user.bot
        bot_pixbuf = get_photo('bot.png')&.pixbuf(width: @icon_size, height: @icon_size)
      end
      visibility_pixbuf = icon_pixbuf
      context.save do
        context.translate(0, @margin)

        if UserConfig[:worldon_show_subparts_bot] && bot_pixbuf
          context.translate(@margin, 0)
          context.set_source_pixbuf(bot_pixbuf)
          context.paint

          context.translate(@icon_size + @margin, 0)
          layout = context.create_pango_layout
          layout.font_description = Pango::FontDescription.new(UserConfig[:mumble_basic_font])
          layout.text = "bot"
          bot_text_width = layout.extents[1].width / Pango::SCALE
          context.set_source_rgb(*(UserConfig[:mumble_basic_color] || [0,0,0]).map{ |c| c.to_f / 65536 })
          context.show_pango_layout(layout)
          context.translate(bot_text_width, 0)
        end

        if UserConfig[:worldon_show_subparts_visibility] && visibility_pixbuf
          context.translate(@margin, 0)

          context.set_source_pixbuf(visibility_pixbuf)
          context.paint

          context.translate(@icon_size + @margin, 0)
          layout = context.create_pango_layout
          layout.font_description = Pango::FontDescription.new(UserConfig[:mumble_basic_font])
          layout.text = visibility_text(helper.message.visibility)
          context.set_source_rgb(*(UserConfig[:mumble_basic_color] || [0,0,0]).map{ |c| c.to_f / 65536 })
          context.show_pango_layout(layout)
        end
      end
    end
  end

  def height
    @height ||= show_icon? ? @icon_size + 2 * @margin : 0
  end
end

