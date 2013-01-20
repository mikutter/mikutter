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
      click_start = []

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
          if last_motioned
            motioned_id = @tree.get_record(motioned[0]).id rescue nil
            last_motioned_id = @tree.get_record(last_motioned[0]).id rescue nil
            if(last_motioned_id and motioned_id != last_motioned_id)
              signal_emit("leave_notify_event", e, *last_motioned) end end
          last_motioned = motioned end }

      tree.ssc("button_press_event") { |w, e|
        path, column, cell_x, cell_y = tree.get_path_at_pos(e.x, e.y)
        click_start = [cell_x, cell_y]
        if column
          armed_column = column
          signal_emit("button_press_event", e, path, column, cell_x, cell_y) end
        e.button == 3 && tree.get_active_pathes.include?(path) # 選択してるものを右クリックした時は、他のセルの選択を解除しない
      }

      tree.ssc("button_release_event") { |w, e|
        path, column, cell_x, cell_y = tree.get_path_at_pos(e.x, e.y)
        if column
          cell_x ||= -1
          cell_y ||= -1
          signal_emit("button_release_event", e, path, column, cell_x, cell_y)
          if click_start.size == 2 and click_start.all?{|x| x.respond_to? :-} and (column == armed_column) and (click_start[0] - cell_x).abs <= 4 and (click_start[1] - cell_y).abs <= 4
            signal_emit("click", e, path, column, cell_x, cell_y) end
          armed_column = nil end }

      last_selected = Set.new(tree.selection.to_enum(:selected_each).map{ |m, p, i| i[3] }).freeze
      tree.selection.ssc("changed") { |this|
        now_selecting = Set.new(this.to_enum(:selected_each).map{ |m, p, i| i[3] }).freeze
        new_selected = now_selecting - last_selected
        unselected = last_selected - now_selecting
        notice "now: #{now_selecting.size} last: #{last_selected.size}"
        new_selected.each(&:on_selected)
        unselected.each(&:on_unselected)
        last_selected = now_selecting
        false }

      event_hooks end

    # Messageに関連付けられた Gdk::MiraclePainter を取得する
    def miracle_painter(message)
      type_strict message => Message
      mid = message[:id].to_s.freeze
      record = @tree.get_record_by_message(message)
      if record and record.miracle_painter
        record.miracle_painter
      else
        @tree.update!(message, Gtk::TimeLine::InnerTL::MIRACLE_PAINTER, create_miracle_painter(message)) end end

    # MiraclePainterを生成して返す
    def create_miracle_painter(message)
      Gdk::MiraclePainter.new(message, avail_width).set_tree(@tree)
    end

    def message_id=(id)
      if id && id.to_i > 0
        message = Message.findbyid(id.to_i, 1)
        if message
          return render_message(message) end end
      self.pixbuf = Gdk::Pixbuf.new(Skin.get('notfound.png')) end

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
      self.pixbuf = miracle_painter(message).pixbuf end

    # 描画するセルの横幅を取得する
    def avail_width
      [@tree.get_column(0).width, 100].max
    end

    def event_hooks
      last_pressed = nil
      ssc(:click, @tree){ |r, e, path, column, cell_x, cell_y|
        record = @tree.get_record(path)
        record.miracle_painter.clicked(cell_x, cell_y, e) if record
        false }
      ssc(:button_press_event, @tree){ |r, e, path, column, cell_x, cell_y|
        if e.button == 1
          record = @tree.get_record(path)
          if record
            last_pressed = record.miracle_painter
            last_pressed.pressed(cell_x, cell_y) end end
        false }
      ssc(:button_release_event, @tree){ |r, e, path, column, cell_x, cell_y|
        if e.button == 1 and last_pressed
          record = @tree.get_record(path)
          if record
            if(last_pressed == record.miracle_painter)
              last_pressed.released(cell_x, cell_y)
            else
              last_pressed.released end end
          last_pressed = nil end
        false }
      ssc(:motion_notify_event, @tree){ |r, e, path, column, cell_x, cell_y|
        record = @tree.get_record(path)
        record.miracle_painter.point_moved(cell_x, cell_y) if record
        false }
      ssc(:leave_notify_event, @tree){ |r, e, path, column, cell_x, cell_y|
        record = @tree.get_record(path)
        record.miracle_painter.point_leaved(cell_x, cell_y) if record
        false }
    end

  end
end
# ~> -:3: undefined method `miquire' for main:Object (NoMethodError)
