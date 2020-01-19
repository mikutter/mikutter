# -*- coding: utf-8 -*-

require File.join(__dir__, "account_control")

Plugin.create :change_account do
  # アカウント変更用の便利なコマンド
  command(:account_previous,
          name: _('前のアカウント'),
          condition: lambda{ |opt| Plugin.collect(:worlds).take(2).to_a.size == 2 },
          visible: true,
          role: :window) do |opt|
    worlds = Plugin.collect(:worlds).to_a
    index = worlds.index(opt.world)
    Plugin.call(:world_change_current, worlds[index - 1]) if index
  end

  command(:account_forward,
          name: _('次のアカウント'),
          condition: lambda{ |opt| Plugin.collect(:worlds).take(2).to_a.size == 2 },
          visible: true,
          role: :window) do |opt|
    worlds = Plugin.collect(:worlds).to_a
    index = worlds.index(opt.world)
    Plugin.call(:world_change_current, worlds[(index + 1) % worlds.size]) if index
  end

  filter_command do |menu|
    Plugin.collect(:worlds).each do |world|
      slug = "switch_account_to_#{world.slug}".to_sym
      menu[slug] = {
        slug: slug,
        exec: -> options {
          Plugin.call(:world_change_current, world)
        },
        plugin: @name,
        name: _('%{title}(%{world}) に切り替える'.freeze) % {
          title: world.title,
          world: world.class.slug
        },
        condition: -> options { true },
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
      Plugin.call(:request_world_add)
      true
    end
    btn_delete.ssc(:clicked) do
      delete_world_with_confirm(listview.selected_worlds)
      true
    end
    listview.ssc(:delete_world) do |widget, worlds|
      delete_world_with_confirm(worlds)
      false
    end
    pack_start(Gtk::HBox.new(false, 4).
                 add(listview).
                 closeup(Gtk::VBox.new.
                           closeup(btn_add).
                           closeup(btn_delete)))
  end

  on_request_world_add do
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
end
