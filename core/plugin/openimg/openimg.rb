# -*- coding: utf-8 -*-

require 'gtk2'
require 'cairo'

module Plugin::Openimg
  ImageOpener = Struct.new(:name, :condition, :open)
end

Plugin.create :openimg do
  # 画像アップロードサービスの画像URLから実際の画像を得る。
  # サービスによってはリファラとかCookieで制御してる場合があるので、
  # "http://twitpic.com/d250g2" みたいなURLから直接画像の内容を返す。
  # String url 画像URL
  # String|nil 画像
  defevent :openimg_raw_image_from_display_url,
           prototype: [String, tcor(IO, nil)]

  # 画像アップロードサービスの画像URLから画像のPixbufを得る。
  defevent :openimg_pixbuf_from_display_url,
           prototype: [String, tcor(:pixbuf, nil), tcor(Thread, nil)]

  # 画像を取得できるURLの条件とその方法を配列で返す
  defevent :openimg_image_openers,
           prototype: [Array]

  # 画像を新しいウィンドウで開く
  defevent :openimg_open,
           priority: :ui_response,
           prototype: [String, Message]

  defdsl :defimageopener do |name, condition, &proc|
    type_strict condition => :===, name => String
    opener = Plugin::Openimg::ImageOpener.new(name.freeze, condition, proc).freeze
    filter_openimg_image_openers do |openers|
      openers << opener
      [openers] end end

  defimageopener(_('画像直リンク'), /.*\.(?:jpg|png|gif|)\Z/i) do |display_url|
    begin
      open(display_url)
    rescue => _
      error _
      nil end end

  filter_openimg_pixbuf_from_display_url do |display_url, loader, thread|
    raw  = Plugin.filtering(:openimg_raw_image_from_display_url, display_url, nil).last
    if raw
      begin
        loader = GdkPixbuf::PixbufLoader.new
        thread = Thread.new do
          begin
            loop do
              Thread.pass
              partial = raw.readpartial(1024*HYDE)
              atomic{ loader.write partial }
            end
            nil
          rescue EOFError
            true
          ensure
            raw.close rescue nil
            loader.close rescue nil end end
        [display_url, loader, thread]
      rescue => _
        error _
        [display_url, loader, thread] end
    else
      [display_url, loader, thread] end end

  filter_openimg_raw_image_from_display_url do |display_url, content|
    unless content
      openers = Plugin.filtering(:openimg_image_openers, Set.new).first
      content = openers.lazy.select{ |opener|
        opener.condition === display_url
      }.map{ |opener|
        opener.open.(display_url)
      }.select(&ret_nth).take(1).force.first end
    [display_url, content] end

  on_openimg_open do |display_url|
    image_surface = loading_surface

    window = ::Gtk::Window.new().
             set_title(display_url).
             set_role('mikutter_image_preview'.freeze).
             set_type_hint(Gdk::Window::TYPE_HINT_DIALOG).
             set_default_size(*default_size)
    w_wrap = ::Gtk::DrawingArea.new
    w_toolbar = ::Gtk::Toolbar.new
    w_browser = ::Gtk::ToolButton.new(Gtk::Image.new(GdkPixbuf::Pixbuf.new(file: Skin.get('forward.png'), width: 24, height: 24)))

    window.ssc(:destroy, &:destroy)
    last_size = nil
    w_wrap.ssc(:size_allocate) do
      if w_wrap.window && last_size != w_wrap.window.geometry[2,2]
        last_size = w_wrap.window.geometry[2,2]
        redraw(w_wrap, image_surface) end
      false end
    w_wrap.ssc(:expose_event) do
      redraw(w_wrap, image_surface)
      true end
    w_browser.ssc(:clicked) do
      Gtk.openurl(display_url)
      false end

    w_toolbar.insert(0, w_browser)
    window.add(Gtk::VBox.new.closeup(w_toolbar).add(w_wrap))
    Thread.new {
      Plugin.filtering(:openimg_pixbuf_from_display_url, display_url, nil, nil)
    }.next { |result|
      if result[1].is_a? GdkPixbuf::PixbufLoader
        _, pixbufloader, thread = result
        pixbufloader.ssc(:area_updated, window) do |_, x, y, width, height|
          Delayer.new do
            if thread.alive?
              image_surface = progress(w_wrap, pixbufloader.pixbuf, image_surface, x: x, y: y, width: width, height: height) end end
          true end

        pixbufloader.ssc(:closed, window) do
          image_surface = progress(w_wrap, pixbufloader.pixbuf, image_surface, paint: true)
          true end

        thread.next { |flag|
          Deferred.fail flag unless flag
        }.trap { |exception|
          error exception
          image_surface = error_surface
        }
      else
        warn "cant open: #{display_url}"
        image_surface = error_surface
        redraw(w_wrap, image_surface) end
    }.trap{ |exception|
      error exception
      image_surface = error_surface
      redraw(w_wrap, image_surface)
    }
    window.show_all end

  def progress(w_wrap, pixbuf, image_surface, x: 0, y: 0, width: 0, height: 0, paint: false)
    return unless pixbuf
    context = nil
    size_changed = false
    unless image_surface.width == pixbuf.width and image_surface.height == pixbuf.height
      size_changed = true
      image_surface = Cairo::ImageSurface.new(pixbuf.width, pixbuf.height)
      context = Cairo::Context.new(image_surface)
      context.save do
        context.set_source_color(Cairo::Color::BLACK)
        context.paint end end
    context ||= Cairo::Context.new(image_surface)
    context.save do
      context.set_source_pixbuf(pixbuf)
      if paint
        context.paint
      else
        context.rectangle(x, y, width, height)
        context.fill end end
    redraw(w_wrap, image_surface, repaint: paint || size_changed)
    image_surface end

  def default_size
    @size || [640, 480] end

  def changesize(w_wrap, window, url)
    w_wrap.remove(w_wrap.children.first)
    @size = window.window.geometry[2,2].freeze
    w_wrap.add(::Gtk::WebIcon.new(url, *@size).show_all)
    @size end

  def redraw(w_wrap, image_surface, repaint: true)
    gdk_window = w_wrap.window
    return unless gdk_window
    ew, eh = gdk_window.geometry[2,2]
    return if(ew == 0 or eh == 0)
    context = gdk_window.create_cairo_context
    context.save do
      if repaint
        context.set_source_color(Cairo::Color::BLACK)
        context.paint end
      if (ew * image_surface.height) > (eh * image_surface.width)
        rate = eh.to_f / image_surface.height
        context.translate((ew - image_surface.width*rate)/2, 0)
      else
        rate = ew.to_f / image_surface.width
        context.translate(0, (eh - image_surface.height*rate)/2) end
      context.scale(rate, rate)
      context.set_source(Cairo::SurfacePattern.new(image_surface))
      context.paint end
  rescue => _
    error _ end

  ::Gtk::TimeLine.addopenway(->_{
                               openers = Plugin.filtering(:openimg_image_openers, Set.new).first
                               openers.any?{ |opener| opener.condition === _ }
                             }) do |shrinked_url, cancel|
    Thread.new do
      url = (Plugin.filtering(:expand_url, [shrinked_url]).first.first rescue shrinked_url)
      Plugin.call(:openimg_open, url) end end

  def addsupport(cond, element_rule = {}, &block); end

  def loading_surface
    surface = Cairo::ImageSurface.from_png(Skin.get('loading.png'))
    surface end

  def error_surface
    surface = Cairo::ImageSurface.from_png(Skin.get('notfound.png'))
    surface end

end
