# -*- coding: utf-8 -*-

require 'gtk2'

module Gtk::InnerTLDarkMatterPurification
  if Gtk::BINDING_VERSION < [1, 2, 1]
    attr_accessor :collect_counter

    def initialize(*args)
      @collect_counter = 256
      super(*args)
    end
  end
end

module Gtk::TimelineDarkMatterPurification
  if Gtk::BINDING_VERSION < [1, 2, 1]
    def initialize(*args)
      super(*args)
      refresh_timer
    end

    # InnerTLをすげ替える。
    def refresh
      notice "timeline refresh"
      scroll = @tl.vadjustment.value
      oldtl = @tl
      @tl = Gtk::TimeLine::InnerTL.new(oldtl)
      remove(@shell)
      @shell = init_tl
      @tl.vadjustment.value = scroll
      pack_start(@shell.show_all)
      @exposing_miraclepainter = []
      oldtl.destroy if not oldtl.destroyed?
    end

    # ある条件を満たしたらInnerTLを捨てて、全く同じ内容の新しいInnerTLにすげ替えるためのイベントを定義する。
    def refresh_timer
      Reserver.new(60) {
        Delayer.new {
          if !@tl.destroyed?
            window_active = Plugin.filtering(:get_windows, []).first.any?(&:has_toplevel_focus?)
            @tl.collect_counter -= 1 if not window_active
            refresh if not(Gtk::TimeLine::InnerTL.current_tl == @tl and window_active and Plugin.filtering(:get_idle_time, nil).first < 3600) and @tl.collect_counter <= (window_active ? -HYDE : 0)
            refresh_timer end } } end

    def tl_model_remove(iter)
      iter[Gtk::TimeLine::InnerTL::MIRACLE_PAINTER].destroy
      @tl.model.remove(iter)
      @tl.collect_counter -= 1
    end
  end
end
