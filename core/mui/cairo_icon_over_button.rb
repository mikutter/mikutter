# -*- coding: utf-8 -*-

def Gdk::IconOverButton(schemer)
  schemer.freeze
  Module.new{

    define_method(:_schemer){ schemer }

    attr_accessor :current_icon_pos

    def index2point(index)
      x, y = _schemer[:x_count], _schemer[:y_count]
      (index / y)*x + index % x
    end

    def get_icon_rectangle(ipx, ipy)
      w, h = pos.main_icon.width / _schemer[:x_count], pos.main_icon.height / _schemer[:y_count]
      Gdk::Rectangle.new(w * ipx, h * ipy, w, h)
    end

    def globalpos2iconpos(gx, gy)
      lx, ly = gx - pos.main_icon.x, gy - pos.main_icon.y
      w, h = pos.main_icon.width / _schemer[:x_count], pos.main_icon.height / _schemer[:y_count]
      [(lx / w).to_i, (ly / h).to_i] end

    def render_icon_over_button(context)
      if(current_icon_pos)
        pb_overbutton = Gdk::Pixbuf.new(MUI::Skin.get("overbutton.png"))
        pb_overbutton_mo = Gdk::Pixbuf.new(MUI::Skin.get("overbutton_mouseover.png"))
        _schemer[:y_count].times{ |posy|
          _schemer[:x_count].times{ |posx|
            pos = [posx, posy]
            ir = get_icon_rectangle(*pos)
            context.save{
              pb = if current_icon_pos == pos
                     pb_overbutton_mo
                   else
                     pb_overbutton end
              context.translate(ir.x, ir.y)
              context.scale(ir.width / pb.width, ir.height / pb.height)
              context.set_source_pixbuf(pb)
              context.paint
            }
            context.save{
              context.translate(ir.x, ir.y)
              icon_pb = Gdk::Pixbuf.new(MUI::Skin.get(iob_icon_pixbuf[posx][posy]))
              context.scale(ir.width / icon_pb.width, ir.height / icon_pb.height)
              context.set_source_pixbuf(icon_pb)
              context.paint
            } } } end end

    def point_moved_main_icon(gx, gy)
      ipx, ipy = ip = globalpos2iconpos(gx, gy)
      if ipx >= 0 and ipx < _schemer[:x_count] and ipy >= 0 and ipy < _schemer[:y_count]
        if current_icon_pos != ip
          on_modify
          @current_icon_pos = ip end
      else
        iob_main_leave
      end
    end

    def iob_main_leave
      if(current_icon_pos)
        @current_icon_pos = nil
        on_modify
      end
    end

    def iob_clicked
      if(current_icon_pos)
        __send__([ [:iob_reply_clicked, :iob_etc_clicked],
                   [:iob_retweet_clicked, :iob_unfav_clicked]][current_icon_pos[0]][current_icon_pos[1]]) end end

  }
end
