class Gdk::SubPartsMastodonStatusInfo < Gdk::SubParts
  DEFAULT_ICON_SIZE = 20

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
    photo&.pixbuf(width: icon_size.width, height: icon_size.height)
  end

  def show_icon?
    return true if (UserConfig[:mastodon_show_subparts_bot] && helper.message.user.respond_to?(:bot) && helper.message.user.bot)
    return true if (UserConfig[:mastodon_show_subparts_pin] && helper.message.respond_to?(:pinned?) && helper.message.pinned?)
    return true if (UserConfig[:mastodon_show_subparts_visibility] && helper.message.respond_to?(:visibility) && filename(helper.message.visibility))
    false
  end

  def visibility_text(visibility)
    case visibility
    when 'unlisted'
      Plugin[:mastodon]._('未収載')
    when 'private'
      Plugin[:mastodon]._('非公開')
    when 'direct'
      Plugin[:mastodon]._('ダイレクト')
    else
      ''
    end
  end

  def initialize(*args)
    super

    @margin = 2
  end

  def render(context)
    if helper.visible? && show_icon?
      if helper.message.user.respond_to?(:bot) && helper.message.user.bot
        bot_pixbuf = get_photo('bot.png')&.pixbuf(width: icon_size.width, height: icon_size.height)
      end
      if helper.message.respond_to?(:pinned?) && helper.message.pinned?
        pin_pixbuf = get_photo('pin.png')&.pixbuf(width: icon_size.width, height: icon_size.height)
      end
      visibility_pixbuf = icon_pixbuf
      context.save do
        context.translate(0, margin)

        if UserConfig[:mastodon_show_subparts_bot] && bot_pixbuf
          context.translate(margin, 0)
          context.set_source_pixbuf(bot_pixbuf)
          context.paint

          context.translate(icon_size.width + margin, 0)
          layout = context.create_pango_layout
          layout.font_description = helper.font_description(UserConfig[:mumble_basic_font])
          layout.text = Plugin[:mastodon]._('bot')
          bot_text_width = layout.extents[1].width / Pango::SCALE
          context.set_source_rgb(*(UserConfig[:mumble_basic_color] || [0,0,0]).map{ |c| c.to_f / 65536 })
          context.show_pango_layout(layout)
          context.translate(bot_text_width, 0)
        end

        if UserConfig[:mastodon_show_subparts_pin] && pin_pixbuf
          context.translate(margin, 0)
          context.set_source_pixbuf(pin_pixbuf)
          context.paint

          context.translate(icon_size.width + margin, 0)
          layout = context.create_pango_layout
          layout.font_description = helper.font_description(UserConfig[:mumble_basic_font])
          layout.text = Plugin[:mastodon]._('ピン留め')
          pin_text_width = layout.extents[1].width / Pango::SCALE
          context.set_source_rgb(*(UserConfig[:mumble_basic_color] || [0,0,0]).map{ |c| c.to_f / 65536 })
          context.show_pango_layout(layout)
          context.translate(pin_text_width, 0)
        end

        if UserConfig[:mastodon_show_subparts_visibility] && visibility_pixbuf
          context.translate(margin, 0)

          context.set_source_pixbuf(visibility_pixbuf)
          context.paint

          context.translate(icon_size.width + margin, 0)
          layout = context.create_pango_layout
          layout.font_description = helper.font_description(UserConfig[:mumble_basic_font])
          layout.text = visibility_text(helper.message.visibility)
          context.set_source_rgb(*(UserConfig[:mumble_basic_color] || [0,0,0]).map{ |c| c.to_f / 65536 })
          context.show_pango_layout(layout)
        end
      end
    end
  end

  def margin
    helper.scale(@margin)
  end

  def icon_size
    @icon_size ||= Gdk::Rectangle.new(0, 0, helper.scale(DEFAULT_ICON_SIZE), helper.scale(DEFAULT_ICON_SIZE))
  end

  def height
    @height ||= show_icon? ? icon_size.height + 2*margin : 0
  end
end

