# -*- coding: utf-8 -*-

miquire :mui, 'miracle_painter'

require 'gtk2'

module Gtk
  class CellRendererMessage < CellRendererPixbuf
    type_register
    install_property(GLib::Param::String.new("message_id", "message_id", "showing message", "hoge", GLib::Param::READABLE|GLib::Param::WRITABLE))

    def initialize()
      super()
      @message = nil
      @miracle_painter = Hash.new
      signal_connect(:click){ |r, e, path, column, cell_x, cell_y|
        miracle_painter(@tree.model.get_iter(path)[1]).clicked(cell_x, cell_y)
        false }
      signal_connect(:button_press_event){ |r, e, path, column, cell_x, cell_y|
        miracle_painter(@tree.model.get_iter(path)[1]).pressed(cell_x, cell_y)
        false }
      signal_connect(:button_release_event){ |r, e, path, column, cell_x, cell_y|
        miracle_painter(@tree.model.get_iter(path)[1]).released(cell_x, cell_y)
        false }
      signal_connect(:motion_notify_event){ |r, e, path, column, cell_x, cell_y|
        miracle_painter(@tree.model.get_iter(path)[1]).point_moved(cell_x, cell_y)
        false }
      signal_connect(:leave_notify_event){ |r, e, path, column, cell_x, cell_y|
        miracle_painter(@tree.model.get_iter(path)[1]).point_leaved(cell_x, cell_y)
        false } end

    # Register events for this Renderer:
    signal_new("button_press_event", GLib::Signal::RUN_FIRST, nil, nil,
               Gdk::EventButton, Gtk::TreePath, Gtk::TreeViewColumn,
               Integer, Integer)

    signal_new("button_release_event", GLib::Signal::RUN_FIRST, nil, nil,
               Gdk::EventButton, Gtk::TreePath, Gtk::TreeViewColumn,
               Integer, Integer)

    signal_new("motion_notify_event", GLib::Signal::RUN_FIRST, nil, nil,
               Gdk::EventButton, Gtk::TreePath, Gtk::TreeViewColumn,
               Integer, Integer)

    signal_new("leave_notify_event", GLib::Signal::RUN_FIRST, nil, nil,
               Gdk::EventButton, Gtk::TreePath, Gtk::TreeViewColumn,
               Integer, Integer)

    signal_new("click", GLib::Signal::RUN_FIRST, nil, nil,
               Gdk::EventButton, Gtk::TreePath, Gtk::TreeViewColumn,
               Integer, Integer)

    def signal_do_button_press_event(event, path, column, cell_x, cell_y)
    end

    def signal_do_button_release_event(event, path, column, cell_x, cell_y)
    end

    def signal_do_motion_notify_event(event, path, column, cell_x, cell_y)
    end

    def signal_do_leave_notify_event(event, path, column, cell_x, cell_y)
    end

    def signal_do_click(event, path, column, cell_x, cell_y)
    end

    def tree=(tree)
      @tree = tree
      tree.add_events(Gdk::Event::BUTTON_PRESS_MASK|Gdk::Event::BUTTON_RELEASE_MASK)
      armed_column = nil
      last_motioned = nil
      tree.signal_connect("leave_notify_event") { |w, e|
        if last_motioned
          signal_emit("leave_notify_event", e, *last_motioned)
          last_motioned = nil end }

      tree.signal_connect("motion_notify_event") { |w, e|
        path, column, cell_x, cell_y = tree.get_path_at_pos(e.x, e.y)
        if column
          armed_column = column
          motioned = [path, column, cell_x, cell_y]
          signal_emit("motion_notify_event", e, *motioned)
          if(last_motioned and @tree.model.get_iter(motioned[0])[0] != @tree.model.get_iter(last_motioned[0])[0])
            signal_emit("leave_notify_event", e, *last_motioned) end
          last_motioned = motioned end }

      tree.signal_connect("button_press_event") { |w, e|
        path, column, cell_x, cell_y = tree.get_path_at_pos(e.x, e.y)
        if column
          armed_column = column
          signal_emit("button_press_event", e, path, column, cell_x, cell_y) end }
      tree.signal_connect("button_release_event") { |w, e|
        path, column, cell_x, cell_y = tree.get_path_at_pos(e.x, e.y)
        if column
          cell_x ||= -1
          cell_y ||= -1
          signal_emit("button_release_event", e, path, column, cell_x, cell_y)
          if (column == armed_column)
            signal_emit("click", e, path, column, cell_x, cell_y)
          end
          armed_column = nil end } end

    attr_reader :message_id, :message

    def miracle_painter(message)
      type_strict message => Message
      @miracle_painter[message[:id].to_i] ||= Gdk::MiraclePainter.new(message, avail_width).set_tree(@tree) end

    def message_id=(id)
      # type_strict id => Integer
      if id && id.to_i > 0
        render_message(Message.findbyid(id.to_i))
      else
        self.pixbuf = Gdk::Pixbuf.new(MUI::Skin.get('notfound.png'))
      end
    end

    def user
      message[:user]
    end

    def render_message(message)
      type_strict message => Message
      if(@tree.realized?)
        h = miracle_painter(message).height
        miracle_painter(message).width = @tree.get_cell_area(nil, @tree.get_column(0)).width
        if(h != miracle_painter(message).height)
          @tree.get_column(0).queue_resize end end
      self.pixbuf = miracle_painter(message).pixbuf
      # set_fixed_size(self.pixbuf.width, self.pixbuf.height)
      # self.width = self.pixbuf.width
      # self.height = self.pixbuf.height
      # @tree.get_column(0).queue_resize
    end

    # 描画するセルの横幅を取得する
    def avail_width
      [@tree.get_column(0).width, 100].max
    end

  end
end
# ~> -:3: undefined method `miquire' for main:Object (NoMethodError)
