# -*- coding: utf-8 -*-

require_relative 'error'
require_relative 'keep'
require_relative 'model/lost_world'

require 'digest/sha1'

Plugin.create(:world) do
  # 登録されている全てのWorldを列挙する。
  # 次のような方法で、Enumeratorを取得できる。
  # ==== Example
  # collect(:worlds)
  defevent :worlds, prototype: [Pluggaloid::COLLECT]

  # 新たなアカウント _1_ を追加する
  defevent :world_create, prototype: [Diva::Model]

  # アカウント _1_ が変更された時に呼ばれる
  defevent :world_modify, prototype: [Diva::Model]

  # アカウント _1_ を削除する
  defevent :world_destroy, prototype: [Diva::Model]

  world_struct = Struct.new(:slug, :name, :proc)
  @world_slug_dict = {}         # world_slug(Symbol) => World URI(Diva::URI)

  defdsl :world_setting do |world_slug, world_name, &proc|
    filter_world_setting_list do |settings|
      [settings.merge(world_slug => world_struct.new(world_slug, world_name, proc))]
    end
  end

  def world_order
    at(:world_order) || []
  end

  def load_world
    Plugin::World::Keep.accounts.map { |id, serialized|
      provider = Diva::Model(serialized[:provider])
      if provider
        provider.new(serialized)
      else
        Miquire::Plugin.load(serialized[:provider])
        provider = Diva::Model(serialized[:provider])
        if provider
          provider.new(serialized)
        else
          activity :system, _('アカウント「%{world}」のためのプラグインが読み込めなかったため、このアカウントは現在利用できません。') % {world: id},
                   description: _('アカウント「%{world}」に必要な%{plugin}プラグインが見つからなかったため、このアカウントは一時的に利用できません。%{plugin}プラグインを意図的に消したのであれば、このアカウントの登録を解除してください。') % {plugin: serialized[:provider], world: id}
          Plugin::World::LostWorld.new(serialized)
        end
      end
    }.compact.freeze.tap(&method(:check_world_uri))
  end

  def worlds_sort(world_list)
    world_list.sort_by.with_index do |a, index|
      [world_order.find_index(world_order_hash(a)) || Float::INFINITY, index]
    end
  end

  def check_world_uri(new_worlds)
    new_worlds.each do |w|
      if @world_slug_dict.key?(w.slug)
        if @world_slug_dict[w.slug] != w.uri
          warn "The URI of World `#{w.slug}' is not defined. You must define a consistent URI for World Model. see: https://dev.mikutter.hachune.net/issues/1231"
        end
      else
        @world_slug_dict[w.slug] = w.uri
      end
    end
  end

  def world_order_hash(world)
    Digest::SHA1.hexdigest("#{world.slug}mikutter")
  end

  collection(:worlds) do |mutation|
    mutation.rewind { |_| worlds_sort(load_world) }

    on_world_create do |new|
      return if new.is_a?(Plugin::World::LostWorld)
      Plugin::World::Keep.account_register(new.slug, { **new.to_hash, provider: new.class.slug })
      mutation.rewind { |_| worlds_sort(load_world) }
      Plugin.call(:world_after_created, new)
      Plugin.call(:service_registered, new) # 互換性のため
    rescue Plugin::World::AlreadyExistError
      description = {
        new_world: new.title,
        duplicated_world: collect(:worlds).find{|w| w.slug == new.slug }&.title,
        world_slug: new.slug }
      activity :system, _('既に登録されているアカウントと重複しているため、登録に失敗しました。'),
               description: _('登録しようとしたアカウント「%{new_world}」は、既に登録されている「%{duplicated_world}」と同じ識別子「%{world_slug}」を持っているため、登録に失敗しました。') % description
    end

    on_world_modify do |target|
      return if target.is_a?(Plugin::World::LostWorld)
      if Plugin::World::Keep.accounts.has_key?(target.slug.to_sym)
        Plugin::World::Keep.account_modify(target.slug, { **target.to_hash, provider: target.class.slug })
        mutation.rewind { |_| worlds_sort(load_world) }
      end
    end

    on_world_destroy do |target|
      Plugin::World::Keep.account_destroy(target.slug)
      mutation.rewind { |_| worlds_sort(load_world) }
      Plugin.call(:service_destroyed, target) # 互換性のため
    end

    # Worldのリストを、 _worlds_ の順番に並び替える。
    on_world_reorder do |new_order|
      store(:world_order, new_order.map(&method(:world_order_hash)))
      mutation.rewind do |worlds|
        worlds_sort(worlds).tap do |reordered|
          Plugin.call(:world_reordered, reordered)
        end
      end
    end
  end
end
