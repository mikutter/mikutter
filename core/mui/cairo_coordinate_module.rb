# -*- coding: utf-8 -*-

require 'gtk2'

# Messageをレンダリングする際の、各パーツの座標の取得設定のためのモジュール
module Gdk::Coordinate
  attr_accessor :width, :color, :icon_width, :icon_height, :icon_margin

  CoordinateStruct = Struct.new(:main_icon, :main_text, :header_text, :reply)

  DEPTH = Gdk::Visual.system.depth

  class Region
    def initialize(x, y, w, h)
      @x, @y, @w, @h = x, y, w, h end

    def point_in?(mx, my)
      left <= mx and mx <= right and top <= my and my <= bottom
    end

    [:x, :y, :w, :h].each{ |node|
      define_method(node){
        n = instance_eval("@#{node}")
        if n.is_a?(Proc)
          n.call
        else
          n end }
      memoize node }

    def bottom
      y + h end

    def right
      x + w end

    alias :left :x
    alias :top :y
    alias :width :w
    alias :height :h
  end

  # 高さを計算して返す
  def height
    @height ||= Hash.new
    @height[width] ||= 
      [(main_message.size[1] + header_left.size[1]) / Pango::SCALE, icon_height].max + icon_margin*2 + subparts_height
  end

  def mainpart_height
    @minpart_height ||= Hash.new
    @minpart_height[width] ||= height - subparts_height - icon_margin
  end

  def reset_height
    if(@height and defined?(@minpart_height) and tree)
      sid = ssc(:modified, tree){
        tree.get_column(0).queue_resize
        signal_handler_disconnect(sid) if signal_handler_is_connected?(sid)
        false }
      @height = @minpart_height = nil
      on_modify end
    self end

  def width=(new)
    if(@width != new)
      @width = [new, 1].max
      on_modify(true) end
    new
  end

  protected

  # 寸法の初期化
  def coordinator(width)
    @width, @color, @icon_width, @icon_height, @icon_margin = [width, 1].max, DEPTH, 48, 48, 2
  end

  # 座標系を構造体にまとめて返す
  def coordinate
    @coordinate ||= CoordinateStruct.new(Region.new(icon_margin, # メインアイコン
                                                    icon_margin,
                                                    icon_width,
                                                    icon_height),
                                         Region.new(icon_width + icon_margin * 2, # つぶやき本文
                                                    lambda{ pos.header_text.bottom },
                                                    width - icon_width - icon_margin * 4,
                                                    0),
                                         Region.new(icon_width + icon_margin * 2, # ヘッダ
                                                    icon_margin,
                                                    width - (icon_width + icon_margin * 4),
                                                    lambda{ header_left.size[1] / Pango::SCALE })
                                         )
  end
  alias :pos :coordinate

end
