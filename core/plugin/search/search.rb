# -*- coding: utf-8 -*-
require_relative 'model/search'

Plugin.create :search do
  intent Plugin::Search::Search do |token|
    Plugin.call(:search_start, token.model.query)
  end

  on_search_start do |query|
    world, = Plugin.filtering(:world_current, nil)
    if search?(world)
      tabslug = :"search_result_#{SecureRandom.uuid}"
      gen_tab(tabslug, query).active!
      start_search(tabslug, query)
    end
  end

  def gen_tab(tabslug, query)
    tab(tabslug, _('「%{query}」の検索結果') % {query: query}) do
      temporary_tab true
      set_icon Skin[:search]
      timeline tabslug
    end
  end

  def start_search(tabslug, query)
    search(world, q: @querybox.text, count: 100).next { |res|
      timeline(tabslug) << res
    }.trap { |e|
      error e
      plugin.timeline(tabslug) << Mikutter::System::Message.new(
        description: _("検索中にエラーが発生しました (%{error})") % {error: e.to_s}
      )
    }
  end
end
