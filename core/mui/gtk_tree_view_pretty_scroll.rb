# -*- coding: utf-8 -*-

require 'gtk2'

# ツリービューにスクロール機能を追加するMixin
# ツリービューの一番上が表示されてる時に一番上にレコードが追加された場合、一番上までゆっくりスクロールする
module Gtk::TreeViewPrettyScroll

  FRAME_PER_SECOND = 30
  FRAME_MS = 1000.to_f / FRAME_PER_SECOND

  def initialize(*a)
    super
    scroll_to_top_animation = false # 自動スクロールアニメーション中なら真
    get_scroll_to_top_animation_id = 0
    scroll_to_top_animation_id = lambda{
      scroll_to_top_animation = false if scroll_to_top_animation
      get_scroll_to_top_animation_id += 1 }

    ssc(:scroll_event){ |this, e|
      case e.direction
      when Gdk::EventScroll::UP
        this.vadjustment.value = [this.vadjustment.value - this.vadjustment.step_increment, this.vadjustment.lower].max
        scroll_to_top_animation_id.call
      when Gdk::EventScroll::DOWN
        @scroll_to_zero_lator = false if this.vadjustment.value == 0
        this.vadjustment.value = [this.vadjustment.value + this.vadjustment.step_increment, this.vadjustment.upper - visible_rect.height].min
        scroll_to_top_animation_id.call end
      false }

    vadjustment.ssc(:value_changed){ |this|
      if(scroll_to_zero? and not(scroll_to_top_animation))
        @scroll_to_zero_lator = false
        my_id = scroll_to_top_animation_id.call
        scroll_to_top_animation = true
        Gtk.timeout_add(FRAME_MS){
          if get_scroll_to_top_animation_id == my_id and not(destroyed?)
            vadjustment.value -= (vadjustment.value / 2) + 1
            scroll_to_top_animation = vadjustment.value > 0.0 end
        } end
      false }

  end

  def scroll_to_zero_lator!
    @scroll_to_zero_lator = true end

  def scroll_to_zero?
    defined?(@scroll_to_zero_lator) and @scroll_to_zero_lator end

end
