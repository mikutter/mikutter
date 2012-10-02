# -*- coding: utf-8 -*-

# DM用のリストビュー
module Plugin::DirectMessage
  class DirectMessage < Gtk::CRUD
    C_CREATED = 2
    C_ICON = 0
    C_TEXT = 1
    C_RAW = 3

    def initialize
      super
      model.set_sort_column_id(DirectMessage::C_CREATED, Gtk::SORT_DESCENDING)
      @creatable = @updatable = false
    end

    def on_deleted(iter)
      Service.primary_service.destroy_direct_message :id => iter[C_RAW][:id]
    end

    def column_schemer
      renderer = nil
      width = nil
      ssc(:expose_event) { |s, e|
        if renderer
          nw =  get_cell_area(nil, get_column(C_TEXT)).width
          if nw != width
            width = nw
            renderer.set_property "wrap-width", nw
            get_column(C_TEXT).queue_resize end end
        false }
      [{:kind => :pixbuf, :type => Gdk::Pixbuf, :label => 'icon'},
       {:kind => :text, :type => String, :label => '本文', :renderer => lambda{ |scheme, index|
           renderer = Gtk::CellRendererText.new
           Delayer.new{
             if not destroyed?
               renderer.set_property "wrap-width", 10
               renderer.set_property "wrap-mode", Pango::WRAP_CHAR end }
           renderer } },
       {:type => Integer},
       {:type => Object},
      ].freeze
    end
  end
end
