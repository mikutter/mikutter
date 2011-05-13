# -*- coding: utf-8 -*-

# Messageをレンダリングする際の、各パーツの座標の取得設定のためのモジュール
module Gdk::Coordinate
  attr_accessor :width, :color, :icon_width, :icon_height, :icon_margin

  CoordinateStruct = Struct.new(:main_icon, :main_text, :header_text)
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
    @height[width] ||= lazy{
      context = dummy_context
      main_layout = main_message(context)
      hl_layout = header_left(context)
      context.show_pango_layout(main_layout)
      context.show_pango_layout(hl_layout)
      [(main_layout.size[1] + hl_layout.size[1]) / Pango::SCALE, icon_height].max + icon_margin * 2
    } end

  def width=(new)
    if(@width != new)
      @width = new
      on_modify(true) end
    new
  end

  protected

  # 寸法の初期化
  def coordinator(width, color = 24)
    @width, @color, @icon_width, @icon_height, @icon_margin = width, 24, 48, 48, 2
    @height = Hash.new
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
                                                    0,
                                                    lambda{ header_left.size[1] / Pango::SCALE })
                                         )
  end
  alias :pos :coordinate

end
