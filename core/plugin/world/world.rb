# -*- coding: utf-8 -*-
require_relative 'error'
require_relative 'keep'
require_relative 'service'

miquire :core, 'environment', 'configloader', 'userconfig'
miquire :lib, 'diva_hacks'

Plugin.create(:world) do

  world_struct = Struct.new(:slug, :name, :proc)

  defdsl :world_setting do |world_slug, world_name, &proc|
    filter_world_setting_list do |settings|
      [settings.merge(world_slug => world_struct.new(world_slug, world_name, proc))]
    end
  end

  # 登録済みアカウントを全て取得するのに使うフィルタ。
  # 登録されているWorld Modelをyielderに格納する。
  filter_worlds do |yielder|
    worlds.each do |world|
      yielder << world
    end
    [yielder]
  end

  # 現在選択されているアカウントに対応するModelを返すフィルタ。
  filter_world_current do |result|
    if result
      [result]
    else
      [current_world]
    end
  end

  # カレントアカウントを _new_ に変更する
  on_world_change_current do |new|
    begin
      if self.current_world != new
        self.current_world = new
        Plugin.call(:primary_service_changed, current_world)
      end
    rescue Plugin::World::InvalidWorldError => err
      error err
    end
  end

  # 新たなアカウント _new_ を追加する
  on_world_create do |new|
    register_world(new)
  end

  # アカウント _target_ が変更された時に呼ばれる
  on_world_modify do |target|
    modify_world(target)
  end

  # アカウント _target_ を削除する
  on_world_destroy do |target|
    destroy_world(target)
  end

  # すべてのWorld Modelを順番通りに含むArrayを返す。
  # 各要素は、アカウントの順番通りに格納されている。
  # 外部からこのメソッド相当のことをする場合は、 _worlds_ フィルタを利用すること。
  # ==== Return
  # [Array] アカウントModelを格納したArray
  def worlds
    @worlds ||= Plugin::World::Keep.accounts.map { |id, serialized|
      provider = Diva::Model(serialized[:provider])
      if provider
        provider.new(serialized)
      else
        Miquire::Plugin.load(serialized[:provider])
        provider = Diva::Model(serialized[:provider])
        if provider
          provider.new(serialized)
        else
          raise "unknown model #{serialized[:provider].inspect}"
        end
      end
    }.freeze
  end

  # 現在選択されているアカウントを返す
  # ==== Return
  # [Diva::Model] カレントアカウント
  def current_world
    if @current
      @current
    elsif worlds.first
      self.current_world = worlds.first
    end
  end

  # カレントアカウントを _new_ に変更する。
  # ==== Args
  # [new]
  #   新たなカレントアカウント(Diva::Model)。
  #   _worlds_ が返す内容のうちのいずれかでなければならない。
  # ==== Return
  # [Diva::Model] 新たなカレントアカウント
  # ==== Raise
  # [Plugin::World::InvalidWorldError] _worlds_ にないアカウントが渡された場合
  def current_world=(new)
    raise Plugin::World::InvalidWorldError unless worlds.include?(new)
    @current = new
  end

  # 新たなアカウントを登録する。
  # ==== Args
  # [new] 追加するアカウント(Diva::Model)
  def register_world(new)
    Plugin::World::Keep.account_register new.slug, new.to_hash.merge(provider: new.class.slug)
    @worlds = nil
    Plugin.call(:service_registered, new) # 互換性のため
  end

  def modify_world(target)
    if Plugin::World::Keep.accounts.has_key? target.slug
      Plugin::World::Keep.account_modify target.slug, target.to_hash.merge(provider: target.class.slug)
      @worlds = nil
    end
  end

  def destroy_world(target)
    Plugin::World::Keep.account_destroy target.slug
    @worlds = nil
    Plugin.call(:service_destroyed, target) # 互換性のため
  end

end
