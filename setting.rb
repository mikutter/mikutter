require_relative 'instance_tab_list'

Plugin.create(:worldon) do
  # 設定
  settings "Worldon" do
    settings "接続" do
      boolean 'ストリーミング接続する', :worldon_enable_streaming
      adjustment '接続間隔（分）', :worldon_rest_interval, 1, 60*24
    end

    settings "公開タイムライン" do
      tablist = Plugin::Worldon::InstanceTabList.new(Plugin[:worldon])
      pack_start(
        Gtk::HBox.new.
        add(tablist).
        closeup(
          Gtk::VBox.new(false, 4).
          closeup(Gtk::Button.new(Gtk::Stock::ADD).tap{ |button|
            button.ssc(:clicked) {
              Plugin.call(:worldon_instances_open_create_dialog)
              true
            }
          }).
          closeup(Gtk::Button.new(Gtk::Stock::EDIT).tap{ |button|
            button.ssc(:clicked) {
              domain = tablist.selected_domain
              if domain
                Plugin.call(:worldon_instances_open_edit_dialog, domain) end
              true
            }
          }).
          closeup(Gtk::Button.new(Gtk::Stock::DELETE).tap{ |button|
            button.ssc(:clicked) {
              domain = tablist.selected_domain
              if domain
                Plugin.call(:worldon_instances_delete_with_confirm, domain) end
              true
            }
          })
        )
      )
      Plugin.create :worldon do
        add_tab_observer = on_worldon_instance_create(&tablist.method(:add_record))
        delete_tab_observer = on_worldon_instance_delete(&tablist.method(:remove_record))
        tablist.ssc(:destroy) do
          detach add_tab_observer
          detach delete_tab_observer end end
    end
  end
end
