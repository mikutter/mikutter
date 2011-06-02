# -*- coding: utf-8 -*-

miquire :mui, 'miracle_painter'

require 'gtk2'

module Gtk
  class CellRendererMessage < CellRendererPixbuf
    type_register
    install_property(GLib::Param::String.new("message_id", "message_id", "showing message", "hoge", GLib::Param::READABLE|GLib::Param::WRITABLE))

    attr_reader :message_id, :message

    def initialize()
      super()
      @message = nil end

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
      tree.ssc("leave_notify_event") { |w, e|
        if last_motioned
          signal_emit("leave_notify_event", e, *last_motioned)
          last_motioned = nil end
        false }

      tree.ssc("motion_notify_event") { |w, e|
        path, column, cell_x, cell_y = tree.get_path_at_pos(e.x, e.y)
        if column
          armed_column = column
          motioned = [path, column, cell_x, cell_y]
          signal_emit("motion_notify_event", e, *motioned)
          if(last_motioned and @tree.get_record(motioned[0]).id != @tree.get_record(last_motioned[0]).id)
            signal_emit("leave_notify_event", e, *last_motioned) end
          last_motioned = motioned end }

      tree.ssc("button_press_event") { |w, e|
        path, column, cell_x, cell_y = tree.get_path_at_pos(e.x, e.y)
        if column
          armed_column = column
          signal_emit("button_press_event", e, path, column, cell_x, cell_y) end }

      tree.ssc("button_release_event") { |w, e|
        path, column, cell_x, cell_y = tree.get_path_at_pos(e.x, e.y)
        if column
          cell_x ||= -1
          cell_y ||= -1
          signal_emit("button_release_event", e, path, column, cell_x, cell_y)
          if (column == armed_column)
            signal_emit("click", e, path, column, cell_x, cell_y) end
          armed_column = nil end }
      event_hooks
    end

    # Messageに関連付けられた Gdk::MiraclePainter を取得する
    def miracle_painter(message)
      type_strict message => Message
      mid = message[:id].to_s.freeze
      record = @tree.get_record_by_message(message)
      if record.miracle_painter
        record.miracle_painter
      else
        @tree.update!(message, Gtk::TimeLine::InnerTL::MIRACLE_PAINTER, create_miracle_painter(message)) end end
      # @tree.model.each{ |model,path,iter|
      #   if(iter[Gtk::TimeLine::InnerTL::MESSAGE_ID] == mid)
      #     if mp = iter[Gtk::TimeLine::InnerTL::MIRACLE_PAINTER]
      #       return mp
      #     else
      #       return iter[Gtk::TimeLine::InnerTL::MIRACLE_PAINTER] = create_miracle_painter(message) end end } end

    # MiraclePainterを生成して返す
    def create_miracle_painter(message)
      Gdk::MiraclePainter.new(message, avail_width).set_tree(@tree)
    end

    def message_id=(id)
      # type_strict id => Integer
      if id && id.to_i > 0
        render_message(Message.findbyid(id.to_i))
      else
        self.pixbuf = Gdk::Pixbuf.new(MUI::Skin.get('notfound.png'))
      end
    end

    private

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

    def event_hooks
      last_pressed = nil
      ssc(:click, @tree){ |r, e, path, column, cell_x, cell_y|
        @tree.get_record(path).miracle_painter.clicked(cell_x, cell_y, e)
        false }
      ssc(:button_press_event, @tree){ |r, e, path, column, cell_x, cell_y|
        if e.button == 1
          last_pressed = @tree.get_record(path).miracle_painter
          last_pressed.pressed(cell_x, cell_y) end
        false }
      ssc(:button_release_event, @tree){ |r, e, path, column, cell_x, cell_y|
        if e.button == 1 and last_pressed
          if(last_pressed == @tree.get_record(path).miracle_painter)
            last_pressed.released(cell_x, cell_y)
          else
            last_pressed.released end
          last_pressed = nil end
        false }
      ssc(:motion_notify_event, @tree){ |r, e, path, column, cell_x, cell_y|
        @tree.get_record(path).miracle_painter.point_moved(cell_x, cell_y)
        false }
      ssc(:leave_notify_event, @tree){ |r, e, path, column, cell_x, cell_y|
        @tree.get_record(path).miracle_painter.point_leaved(cell_x, cell_y)
        false }
    end

  end
end
# ~> -:3: undefined method `miquire' for main:Object (NoMethodError)
