# -*- coding: utf-8 -*-

require File.join(File.dirname(__FILE__), "account_control")

Plugin.create :change_account do
  # アカウント変更用の便利なコマンド
  command(:account_previous,
          name: _('前のアカウント'),
          condition: lambda{ |opt| Service.instances.size >= 2 },
          visible: true,
          role: :window) do |opt|
    index = Service.instances.index(Service.primary)
    if index
      max = Service.instances.size
      Service.set_primary(Service.instances[(max + index - 1) % max])
    elsif not Service.instances.empty?
      Service.set_primary(Service.instances.first) end
  end

  command(:account_forward,
          name: _('次のアカウント'),
          condition: lambda{ |opt| Service.instances.size >= 2 },
          visible: true,
          role: :window) do |opt|
    index = Service.instances.index(Service.primary)
    if index
      Service.set_primary(Service.instances[(index + 1) % Service.instances.size])
    elsif not Service.instances.empty?
      Service.set_primary(Service.instances.first) end
  end

  filter_command do |menu|
    Enumerator.new{|y|
      Plugin.filtering(:worlds, y)
    }.each do |world|
      slug = "switch_account_to_#{world.slug}".to_sym
      menu[slug] = {
        slug: slug,
        exec: -> options {},
        plugin: @name,
        name: _('%{title}(%{world}) に切り替える'.freeze) % {
          title: world.title,
          world: world.class.slug
        },
        condition: -> options {},
        visible: false,
        role: :window,
        icon: world.icon } end
    [menu] end

  # サブ垢は心の弱さ
  settings _('アカウント情報') do
    listview = ::Plugin::ChangeAccount::AccountControl.new(self)
    btn_add = Gtk::Button.new(Gtk::Stock::ADD)
    btn_delete = Gtk::Button.new(Gtk::Stock::DELETE)
    btn_add.ssc(:clicked) do
      boot_wizard
      true
    end
    btn_delete.ssc(:clicked) do
      true
    end
    listview.ssc(:delete_world) do |widget, worlds|
      delete_world_with_confirm(worlds)
      false
    end
    pack_start(Gtk::HBox.new(false, 4).
                 add(listview).
                 closeup(Gtk::HBox.new.
                           add(btn_add)))
  end

  def boot_wizard
    dialog(_('アカウント追加')){
      select 'Select world', :world do
        worlds, = Plugin.filtering(:world_setting_list, Hash.new)
        worlds.values.each do |world|
          option world, world.name
        end
      end
      step1 = await_input

      selected_world = step1[:world]
      instance_eval(&selected_world.proc)
    }.next{ |res|
      Plugin.call(:world_create, res.result)
    }.trap{ |err|
      error err
    }
  end

  def delete_world_with_confirm(worlds)
    dialog(_("アカウントの削除")){
      label _("以下のアカウントを本当に削除しますか？\n一度削除するともう戻ってこないよ")
      worlds.each{ |world|
        link world
      }
    }.next{
      worlds.each{ |world|
        Plugin.call(:world_destroy, world)
      }
    }
  end

  defachievement(:tutorial,
                 description: _("mikutterのチュートリアルを見た"),
                 hint: 'Worldを登録してみよう（開発用超絶手抜き説明）'
                ) do |ach|
    on_world_create do |world|
      ach.take!
    end
  end

end
