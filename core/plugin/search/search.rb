# -*- coding: utf-8 -*-
require_relative 'model/search'
require_relative 'query_box'

Plugin.create :search do
  intent Plugin::Search::Search do |token|
    Plugin.call(:search_start, token.model.query)
  end

  Delayer.new do
    refresh_tab
  end

  on_world_after_created do |world|
    refresh_tab
  end

  on_world_destroy do |world|
    refresh_tab
  end

  def refresh_tab
    if Enumerator.new{|y| Plugin.filtering(:worlds, y) }.any?{|w| w.class.slug == :twitter }
      present_tab
    else
      absent_tab
    end
  end

  def present_tab
    query_box = Plugin::Search::QueryBox.new(self)
    @tag ||= handler_tag do
      tab(:search, _("検索")) do
        set_icon Skin['search.png']
        shrink
        nativewidget query_box
        expand
        timeline :search
      end

      on_search_start do |query|
        query_box.search!(query)
        timeline(:search).active! end
    end
  end

  def absent_tab
    if @tag
      tab(:search).destroy
      detach(@tag)
      @tag = nil
    end
  end
end




