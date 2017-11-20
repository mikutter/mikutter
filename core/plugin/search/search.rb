# -*- coding: utf-8 -*-
require_relative 'model/search'

Plugin.create :search do
  intent Plugin::Search::Search do |token|
    Plugin.call(:search_start, token.model.query)
  end

  defspell(:search, :twitter) do |twitter, options|
    twitter.search(options)
  end

  querybox = ::Gtk::Entry.new()
  querycont = ::Gtk::VBox.new(false, 0)
  searchbtn = ::Gtk::Button.new(_('検索'))
  savebtn = ::Gtk::Button.new(_('保存'))

  querycont.
    closeup(::Gtk::HBox.new(false, 0).
            pack_start(querybox).
            closeup(searchbtn)).
    closeup(::Gtk::HBox.new(false, 0).
            closeup(savebtn))

  tab(:search, _("検索")) do
    set_icon Skin['search.png']
    shrink
    nativewidget querycont
    expand
    timeline :search
  end

  on_search_start do |query|
    querybox.text = query
    searchbtn.clicked
    timeline(:search).active! end

  querybox.signal_connect('activate'){ |elm|
    searchbtn.clicked }

  searchbtn.signal_connect('clicked'){ |elm|
    elm.sensitive = querybox.sensitive = false
    timeline(:search).clear
    spell(:search, Service.primary, q: querybox.text, count: 100).next{ |res|
      timeline(:search) << res if res.is_a? Array
      elm.sensitive = querybox.sensitive = true
    }.trap{ |e|
      error e
      timeline(:search) << Mikutter::System::Message.new(description: _("検索中にエラーが発生しました (%{error})" % {error: e.to_s}))
      elm.sensitive = querybox.sensitive = true } }

  savebtn.signal_connect('clicked'){ |elm|
    query = querybox.text
    Service.primary.search_create(query: query).next{ |saved_search|
      Plugin.call(:saved_search_register, saved_search[:id], query, Service.primary)
    }.terminate(_("検索キーワード「%{query}」を保存できませんでした。あとで試してみてください" % {query: query})) }

end




