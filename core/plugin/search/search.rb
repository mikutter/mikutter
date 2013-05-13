# -*- coding: utf-8 -*-

Plugin.create :search do
  querybox = ::Gtk::Entry.new()
  querycont = ::Gtk::VBox.new(false, 0)
  searchbtn = ::Gtk::Button.new('検索')
  savebtn = ::Gtk::Button.new('保存')

  querycont.
    closeup(::Gtk::HBox.new(false, 0).
            pack_start(querybox).
            closeup(searchbtn)).
    closeup(::Gtk::HBox.new(false, 0).
            closeup(savebtn))

  tab(:search, "検索") do
    set_icon Skin.get("search.png")
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
    Service.primary.search(q: querybox.text, rpp: 100).next{ |res|
      timeline(:search) << res if res.is_a? Array
      elm.sensitive = querybox.sensitive = true
    }.trap{ |e|
      timeline(:search) << Message.new(message: "検索中にエラーが発生しました (#{e.to_s})", system: true)
      elm.sensitive = querybox.sensitive = true } }

  savebtn.signal_connect('clicked'){ |elm|
    query = querybox.text
    Service.primary.search_create(query: query).next{ |saved_search|
      Plugin.call(:saved_search_regist, saved_search[:id], query)
    }.terminate("検索キーワード「#{query}」を保存できませんでした。あとで試してみてください") }

  Message::Entity.addlinkrule(:hashtags, /(?:#|＃)[a-zA-Z0-9_]+/, :search_hashtag){ |segment|
    Plugin.call(:search_start, '#' + segment[:url].match(/^(?:#|＃)?(.+)$/)[1])
  }
end
