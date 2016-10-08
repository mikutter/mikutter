# -*- coding: utf-8 -*-

module Plugin::Openimg
  class Window < Gtk::Window
    attr_reader :album

    def initialize(album, next_opener)
      super()
      @album = album
      @image_surface = loading_surface
      @next_opener = next_opener
      window_settings
      ssc(:destroy, &:destroy)
    end

    def start_loading
      Thread.new {
        Plugin.filtering(:openimg_pixbuf_from_display_url, album, nil, nil)
      }.next { |_, pixbufloader, complete_promise|
        if pixbufloader.is_a? Gdk::PixbufLoader
          rect = nil
          pixbufloader.ssc(:area_updated, self) do |_, x, y, width, height|
            if rect
              rect[:left] = [rect[:left], x].min
              rect[:top] = [rect[:top], y].min
              rect[:right] = [rect[:right], x+width].max
              rect[:bottom] = [rect[:bottom], y+height].max
            else
              rect = {left: x, top: y, right: x+width, bottom: y+height}
              Delayer.new do
                progress(pixbufloader.pixbuf,
                         x: rect[:left],
                         y: rect[:top],
                         width: rect[:right] - rect[:left],
                         height: rect[:bottom] - rect[:top])
                rect = nil
              end
            end
            true end

          pixbufloader.ssc(:closed, self) do
            progress(pixbufloader.pixbuf, paint: true)
            true end

          complete_promise.trap { |exception|
            @image_surface = error_surface
            redraw(repaint: true)
          }
        else
          warn "cant open: #{album}"
          @image_surface = error_surface
          redraw(repaint: true) end
      }.trap{ |exception|
        error exception
        @image_surface = error_surface
        redraw(repaint: true)
      }
      self
    end

    private

    def window_settings
      set_title(album.perma_link.to_s)
      set_role('mikutter_image_preview'.freeze)
      set_type_hint(Gdk::Window::TYPE_HINT_DIALOG)
      set_default_size(*default_size)
      add(Gtk::VBox.new.closeup(w_toolbar).add(w_wrap))
    end

    def redraw(repaint: true)
      return if w_wrap.destroyed?
      gdk_window = w_wrap.window
      return unless gdk_window
      ew, eh = gdk_window.geometry[2,2]
      return if(ew == 0 or eh == 0)
      context = gdk_window.create_cairo_context
      context.save do
        if repaint
          context.set_source_color(Cairo::Color::BLACK)
          context.paint end
        if (ew * @image_surface.height) > (eh * @image_surface.width)
          rate = eh.to_f / @image_surface.height
          context.translate((ew - @image_surface.width*rate)/2, 0)
        else
          rate = ew.to_f / @image_surface.width
          context.translate(0, (eh - @image_surface.height*rate)/2) end
        context.scale(rate, rate)
        context.set_source(Cairo::SurfacePattern.new(@image_surface))
        context.paint end
    rescue => _
      error _ end

    def progress(pixbuf, x: 0, y: 0, width: 0, height: 0, paint: false)
      return unless pixbuf
      context = nil
      size_changed = false
      unless @image_surface.width == pixbuf.width and @image_surface.height == pixbuf.height
        size_changed = true
        @image_surface = Cairo::ImageSurface.new(pixbuf.width, pixbuf.height)
        context = Cairo::Context.new(@image_surface)
        context.save do
          context.set_source_color(Cairo::Color::BLACK)
          context.paint end end
      context ||= Cairo::Context.new(@image_surface)
      context.save do
        context.set_source_pixbuf(pixbuf)
        if paint
          context.paint
        else
          context.rectangle(x, y, width, height)
          context.fill end end
      redraw(repaint: paint || size_changed)
    end

    #
    # === Widgetたち
    #

    def w_wrap
      @w_wrap ||= ::Gtk::DrawingArea.new.tap{|w|
        w.ssc(:size_allocate, &gen_wrap_size_allocate)
        w.ssc(:expose_event, &gen_wrap_expose_event)
      }
    end

    def w_toolbar
      @w_toolbar ||= ::Gtk::Toolbar.new.tap{|w| w.insert(0, w_browser) }
    end

    def w_browser
      @w_browser ||= ::Gtk::ToolButton.new(
        Gtk::Image.new(GdkPixbuf::Pixbuf.new(file: Skin.get('forward.png'), width: 24, height: 24))
      ).tap{|w|
        w.ssc(:clicked, &gen_browser_clicked)
      }
    end

    #
    # === イベントハンドラ
    #

    def gen_browser_clicked
      proc do
        Plugin.call(:open, @next_opener)
        false
      end
    end

    def gen_wrap_expose_event
      proc do |widget|
        redraw(repaint: true)
        true
      end
    end

    def gen_wrap_size_allocate
      last_size = nil
      proc do |widget|
        if widget.window && last_size != widget.window.geometry[2,2]
          last_size = widget.window.geometry[2,2]
          redraw(repaint: true)
        end
        false
      end
    end

    #
    # === その他
    #

    def default_size
      @size || [640, 480]
    end

    def loading_surface
      surface = Cairo::ImageSurface.from_png(Skin.get('loading.png'))
      surface
    end

    def error_surface
      surface = Cairo::ImageSurface.from_png(Skin.get('notfound.png'))
      surface
    end

  end
end
