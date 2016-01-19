# -*- coding: utf-8 -*-

module Plugin::MessageInspector
  class HeaderWidget < Gtk::EventBox
    def initialize(message, *args)
      super(*args)
      ssc(:visibility_notify_event, &widget_style_setter)
      add(Gtk::VBox.new(false, 0)
           .closeup(Gtk::HBox.new(false, 0).
                     closeup(Gtk::WebIcon.new(message.user.profile_image_url_large, 48, 48).top).
                     closeup(Gtk::VBox.new(false, 0).
                              closeup(Gtk::Label.new(message.user.idname).left).
                              closeup(Gtk::Label.new(message.user[:name]).left))).
           closeup(Gtk::IntelligentTextview.new(message.to_s, 'font' => :mumble_basic_font)))
    end

    private
    def widget_style_setter
      ->(widget, *_rest) do
        widget.style = background_color
        false end end

    def background_color
      style = Gtk::Style.new()
      style.set_bg(Gtk::STATE_NORMAL, 0xFFFF, 0xFFFF, 0xFFFF)
      style end
  end
end
