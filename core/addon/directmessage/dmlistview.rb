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
    end

    def column_schemer
      [{:kind => :pixbuf, :type => Gdk::Pixbuf, :label => 'icon'},
       {:kind => :text, :type => String, :label => '本文'},
       {:type => Integer},
       {:type => Object},
      ].freeze
    end
  end
end
