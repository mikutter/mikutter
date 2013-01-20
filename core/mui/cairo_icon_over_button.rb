# -*- coding: utf-8 -*-

require 'gtk2'

=begin rdoc
  アイコン上にボタンを表示するためのモジュール
=end
module Gdk::IconOverButton

  attr_accessor :current_icon_pos

  def _schemer
    {x_count: 2, y_count: 2} end

  # アイコンインデックスからアイコンの左上座標を計算する
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

  # _context_ にicon over buttonを描画する。
  def render_icon_over_button(context)
    pb_overbutton = Gdk::Pixbuf.new(Skin.get("overbutton.png"))
    pb_overbutton_mo = Gdk::Pixbuf.new(Skin.get("overbutton_mouseover.png"))
    context.save{
      context.translate(pos.main_icon.x, pos.main_icon.y)
      _schemer[:y_count].times{ |posy|
        _schemer[:x_count].times{ |posx|
          pos = [posx, posy]
          ir = get_icon_rectangle(*pos)
          icon_file_name = (current_icon_pos ? iob_icon_pixbuf : iob_icon_pixbuf_off)[posx][posy]
          if(icon_file_name)
            if(current_icon_pos)
              context.save{
                pb = if current_icon_pos == pos
                       pb_overbutton_mo
                     else
                       pb_overbutton end
                context.translate(ir.x, ir.y)
                context.scale(ir.width.to_f / pb.width, ir.height.to_f / pb.height)
                context.set_source_pixbuf(pb)
                context.paint } end
            context.save{
              context.translate(ir.x, ir.y)
              icon_pb = Gdk::Pixbuf.new(Skin.get(icon_file_name))
              context.scale(ir.width.to_f / icon_pb.width, ir.height.to_f / icon_pb.height)
              context.set_source_pixbuf(icon_pb)
              context.paint } end } } } end

  # アイコン上でマウスポインタが動いた時に呼ぶ。
  # - _gx_ MiraclePainter全体から見たx座標
  # - _gy_MiraclePainter 全体から見たy座標
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

  # icon over buttonからマウスポインタが離れたときに呼ぶ。
  def iob_main_leave
    if(current_icon_pos)
      @current_icon_pos = nil
      on_modify
    end
  end

  # icon over buttonがクリックされたことを通知する。
  # 最後に point_moved_main_icon() が呼ばれた箇所がクリックされたことになる
  def iob_clicked
    if(current_icon_pos)
      __send__([ [:iob_reply_clicked, :iob_etc_clicked],
                 [:iob_retweet_clicked, :iob_fav_clicked]][current_icon_pos[0]][current_icon_pos[1]]) end end

end
