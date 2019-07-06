require_relative 'instance_setting_list'

Plugin.create(:mastodon) do
  pm = Plugin::Mastodon

  # 設定の初期化
  defaults = {
    mastodon_enable_streaming: true,
    mastodon_rest_interval: UserConfig[:retrieve_interval_friendtl],
    mastodon_show_subparts_visibility: true,
    mastodon_show_subparts_bot: true,
    mastodon_show_subparts_pin: true,
    mastodon_instances: Hash.new,
  }
  defaults.each do |key, value|
    if UserConfig[key].nil?
      UserConfig[key] = value
    end
  end

  instance_config = at(:instances)
  if instance_config
    UserConfig[:mastodon_instances] = instance_config.merge(UserConfig[:mastodon_instances])
    store(:instances, nil)
  end


  # 追加
  on_mastodon_instances_open_create_dialog do
    dialog _('サーバー設定の追加') do
      error_msg = nil
      while true
        if error_msg
          label error_msg
        end
        input _('サーバーのドメイン'), :domain
        result = await_input
        if result[:domain].empty?
          error_msg = _('ドメイン名を入力してください。')
          next
        end
        if UserConfig[:mastodon_instances].has_key?(result[:domain])
          error_msg = _('既に登録済みのドメインです。入力し直してください。')
          next
        end
        instance = await pm::Instance.add(result[:domain]).trap{ nil }
        if instance.nil?
          error_msg = _('接続に失敗しました。もう一度確認してください。')
          next
        end

        break
      end
      domain = result[:domain]
      label _('%{domain} サーバーを追加しました') % {domain: domain}
      Plugin.call(:mastodon_restart_instance_stream, domain)
      Plugin.call(:mastodon_instance_created, domain)
    end
  end

  # 編集
  on_mastodon_instances_open_edit_dialog do |domain|
    config = UserConfig[:mastodon_instances][domain]

    dialog _('サーバー設定の編集') do
      label _('サーバーのドメイン： %{domain}') % {domain: domain}
    end.next do |result|
      Plugin.call(:mastodon_update_instance, result.domain)
    end
  end

  # 削除
  on_mastodon_instances_delete_with_confirm do |domain|
    next if UserConfig[:mastodon_instances][domain].nil?
    dialog _('サーバー設定の削除') do
      label _('サーバー %{domain} を削除しますか？') % {domain: domain}
    end.next {
      Plugin.call(:mastodon_delete_instance, domain)
    }
  end

  # 設定
  settings _('Mastodon') do
    settings _('表示') do
      boolean _('botアカウントにアイコンを表示する'), :mastodon_show_subparts_bot
      boolean _('ピン留めトゥートにアイコンを表示する'), :mastodon_show_subparts_pin
      boolean _('トゥートに公開範囲を表示する'), :mastodon_show_subparts_visibility
    end

    settings _('接続') do
      boolean _('ストリーミング接続する'), :mastodon_enable_streaming
      adjustment _('接続間隔（分）'), :mastodon_rest_interval, 1, 60*24
    end

    settings _('公開タイムライン') do
      treeview = Plugin::Mastodon::InstanceSettingList.new
      btn_add = Gtk::Button.new(Gtk::Stock::ADD)
      btn_delete = Gtk::Button.new(Gtk::Stock::DELETE)
      btn_add.ssc(:clicked) do
        Plugin.call(:mastodon_instances_open_create_dialog)
        true
      end
      btn_delete.ssc(:clicked) do
        domain = treeview.selected_domain
        if domain
          Plugin.call(:mastodon_instances_delete_with_confirm, domain) end
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
      Plugin.create :mastodon do
        pm = Plugin::Mastodon

        add_tab_observer = on_mastodon_instance_created(&treeview.method(:add_record))
        delete_tab_observer = on_mastodon_delete_instance(&treeview.method(:remove_record))
        treeview.ssc(:destroy) do
          detach add_tab_observer
          detach delete_tab_observer
        end
      end
    end
  end
end
