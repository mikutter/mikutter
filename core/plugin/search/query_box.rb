# -*- coding: utf-8 -*-

module Plugin::Search
  class QueryBox < Gtk::VBox
    def initialize
      super(false, 0)
      querybox = ::Gtk::Entry.new()
      searchbtn = ::Gtk::Button.new(Plugin[:search]._('検索'))
      savebtn = ::Gtk::Button.new(Plugin[:search]._('保存'))

      closeup(::Gtk::HBox.new(false, 0).
                pack_start(querybox).
                closeup(searchbtn))
      closeup(::Gtk::HBox.new(false, 0).
                closeup(savebtn))

      querybox.signal_connect('activate'){ |elm|
        searchbtn.clicked }

      searchbtn.signal_connect('clicked'){ |elm|
        elm.sensitive = querybox.sensitive = false
        timeline(:search).clear
        search(Service.primary, q: querybox.text, count: 100).next{ |res|
          timeline(:search) << res if res.is_a? Array
          elm.sensitive = querybox.sensitive = true
        }.trap{ |e|
          error e
          timeline(:search) << Mikutter::System::Message.new(description: Plugin[:search]._("検索中にエラーが発生しました (%{error})") % {error: e.to_s})
          elm.sensitive = querybox.sensitive = true } }

      savebtn.signal_connect('clicked'){ |elm|
        query = querybox.text
        Service.primary.search_create(query: query).next{ |saved_search|
          Plugin.call(:saved_search_register, saved_search[:id], query, Service.primary)
        }.terminate(Plugin[:search]._("検索キーワード「%{query}」を保存できませんでした。あとで試してみてください") % {query: query}) }
    end

    def text
      querybox.text
    end

    def text=(new_text)
      querybox.text = new_text
    end
  end
end
