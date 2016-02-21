# -*- coding: utf-8 -*-

module Plugin::MessageInspector
  class HeaderWidget < Gtk::EventBox
    def initialize(message, *args)
      super(*args)
      ssc_atonce(:visibility_notify_event, &widget_style_setter)
      add(Gtk::VBox.new(false, 0).
           closeup(Gtk::HBox.new(false, 8).
                     closeup(icon(message.user).top).
                     closeup(Gtk::VBox.new(false, 0).
                              closeup(idname(message.user).left).
                              closeup(Gtk::Label.new(message.user[:name]).left))).
           closeup(post_date(message).right))
    end

    private

    def background_color
      style = Gtk::Style.new()
      style.set_bg(Gtk::STATE_NORMAL, 0xFFFF, 0xFFFF, 0xFFFF)
      style end

    def icon(user)
      type_strict user.profile_image_url_large => String
      icon = Gtk::EventBox.new.
        add(Gtk::WebIcon.new(user.profile_image_url_large, 48, 48))
      icon.ssc(:button_press_event, &icon_opener(user.profile_image_url_large))
      icon.ssc_atonce(:realize, &cursor_changer(Gdk::Cursor.new(Gdk::Cursor::HAND2)))
      icon.ssc_atonce(:visibility_notify_event, &widget_style_setter)
      icon end

    def idname(user)
      label = Gtk::EventBox.new.
              add(Gtk::Label.new.
                   set_markup("<b><u><span foreground=\"#0000ff\">#{Pango.escape(user.idname)}</span></u></b>"))
      label.ssc(:button_press_event, &profile_opener(user))
      label.ssc_atonce(:realize, &cursor_changer(Gdk::Cursor.new(Gdk::Cursor::HAND2)))
      label.ssc_atonce(:visibility_notify_event, &widget_style_setter)
      label end

    def post_date(message)
      label = Gtk::EventBox.new.
              add(Gtk::Label.new(message.created.strftime('%Y/%m/%d %H:%M:%S')))
      label.ssc(:button_press_event, &message_opener(message))
      label.ssc_atonce(:realize, &cursor_changer(Gdk::Cursor.new(Gdk::Cursor::HAND2)))
      label.ssc_atonce(:visibility_notify_event, &widget_style_setter)
      label end

    def icon_opener(url)
      type_strict url => String
      proc do
        Plugin.call(:openimg_open, url)
        true end end

    def profile_opener(user)
      type_strict user => User
      proc do
        Plugin.call(:show_profile, Service.primary, user)
        true end end

    def message_opener(message)
      type_strict message => Message
      proc do
        Gtk.openurl(message.perma_link)
        true end end

    memoize def cursor_changer(cursor)
      proc do |w|
        w.window.cursor = cursor
        false end end

    memoize def widget_style_setter
      ->(widget, *_rest) do
        widget.style = background_color
        false end end

  end
end
