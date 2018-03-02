require_relative 'instance_setting_list'

Plugin.create(:worldon) do
  pm = Plugin::Worldon

  # 設定の初期化
  defaults = {
    worldon_enable_streaming: true,
    worldon_rest_interval: UserConfig[:retrieve_interval_friendtl],
    worldon_show_subparts_visibility: true,
    worldon_instances: Hash.new,
  }
  defaults.each do |key, value|
    if UserConfig[key].nil?
      UserConfig[key] = value
    end
  end

  instance_config = at(:instances)
  if instance_config
    UserConfig[:worldon_instances] = instance_config.merge(UserConfig[:worldon_instances])
    store(:instances, nil)
  end


  # 追加
  on_worldon_instances_open_create_dialog do
    dialog "インスタンス設定の追加" do
      error_msg = nil
      while true
        if error_msg
          label error_msg
        end
        input "インスタンスのドメイン", :domain
        result = await_input
        if result[:domain].empty?
          error_msg = "ドメイン名を入力してください。"
          next
        end
        if UserConfig[:worldon_instances].has_key?(result[:domain])
          error_msg = "既に登録済みのドメインです。入力し直してください。"
          next
        end
        instance, = Plugin.filtering(:worldon_add_instance, result[:domain])
        if instance.nil?
          error_msg = "接続に失敗しました。もう一度確認してください。"
          next
        end

        break
      end
      domain = result[:domain]
      label "#{domain} インスタンスを追加しました"
      Plugin.call(:worldon_restart_instance_stream, domain)
      Plugin.call(:worldon_instance_created, domain)
    end
  end

  # 編集
  on_worldon_instances_open_edit_dialog do |domain|
    config = UserConfig[:worldon_instances][domain]

    dialog "インスタンス設定の編集" do
      label "インスタンスのドメイン： #{domain}"
    end.next do |result|
      Plugin.call(:worldon_update_instance, result.domain)
    end
  end

  # 削除
  on_worldon_instances_delete_with_confirm do |domain|
    next if UserConfig[:worldon_instances][domain].nil?
    dialog "インスタンス設定の削除" do
      label "インスタンス #{domain} を削除しますか？"
    end.next {
      Plugin.call(:worldon_delete_instance, domain)
    }
  end

  # 設定
  settings "Worldon" do
    settings "表示" do
      boolean 'トゥートに公開範囲を表示する', :worldon_show_subparts_visibility
    end

    settings "接続" do
      boolean 'ストリーミング接続する', :worldon_enable_streaming
      adjustment '接続間隔（分）', :worldon_rest_interval, 1, 60*24
    end

    settings "公開タイムライン" do
      treeview = Plugin::Worldon::InstanceSettingList.new
      btn_add = Gtk::Button.new(Gtk::Stock::ADD)
      btn_delete = Gtk::Button.new(Gtk::Stock::DELETE)
      btn_add.ssc(:clicked) do
        Plugin.call(:worldon_instances_open_create_dialog)
        true
      end
      btn_delete.ssc(:clicked) do
        domain = treeview.selected_domain
        if domain
          Plugin.call(:worldon_instances_delete_with_confirm, domain) end
        true
      end
      scrollbar = ::Gtk::VScrollbar.new(treeview.vadjustment)
      pack_start(
        Gtk::HBox.new(false, 4).
        add(treeview).
        closeup(scrollbar).
        closeup(
          Gtk::VBox.new.
          closeup(btn_add).
          closeup(btn_delete)))
      Plugin.create :worldon do
        pm = Plugin::Worldon

        add_tab_observer = on_worldon_instance_created(&treeview.method(:add_record))
        delete_tab_observer = on_worldon_delete_instance(&treeview.method(:remove_record))
        treeview.ssc(:destroy) do
          detach add_tab_observer
          detach delete_tab_observer
        end
      end
    end
  end
end
