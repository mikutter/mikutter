# -*- coding: utf-8 -*-
require_relative 'model/search'

Plugin.create :search do
  intent Plugin::Search::Search, label: _('検索') do |intent_token|
    Plugin.call(:search_open_search_tab, intent_token.model.world, intent_token.model.query)
  end

  filter_quickstep_query do |query, yielder|
    if /\S/.match?(query)
      Enumerator.new { |y| Plugin.filtering(:worlds, y) }.each do |world|
        if search?(world)
          yielder << Plugin::Search::Search.new(query: query, world: world)
        end
      end
    end
    [query, yielder]
  end

  on_search_open_search_tab do |world, query|
    if search?(world)
      tabslug = :"search_result_#{SecureRandom.uuid}"
      gen_tab(tabslug, query).active!
      start_search(tabslug, query, world)
    end
  end

  def gen_tab(tabslug, query)
    tab(tabslug, _('「%{query}」の検索結果') % {query: query}) do
      set_deletable true
      temporary_tab true
      set_icon Skin[:search]
      timeline tabslug
    end
  end

  def start_search(tabslug, query, world)
    search(world, q: query, count: 100).next { |res|
      timeline(tabslug) << res
    }.trap { |e|
      error e
      timeline(tabslug) << Mikutter::System::Message.new(
        description: _("検索中にエラーが発生しました (%{error})") % {error: e.to_s}
      )
    }
  end
end
