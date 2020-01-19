# -*- coding: utf-8 -*-

require_relative 'error'

Plugin.create(:current_world) do
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
    if self.current_world != new
      self.current_world = new
      Plugin.call(:primary_service_changed, current_world)
    end
  rescue Plugin::CurrentWorld::WorldNotfoundError
    activity :system, _('アカウントを存在しないアカウント(%{uri})に切り替えようとしました') % {uri: new&.uri || 'nil'},
             description: _('アカウントを切り替えようとしましたが、切り替えようとしたアカウントは存在しませんでした。') + "\n\n" +
             _("切り替え先のアカウント:\n%{uri}") % {uri: new&.uri || 'nil'} + "\n\n" +
             _('現在存在するアカウント:') + "\n" +
             Plugin.collect(:worlds).map{|w| "#{w.slug} (#{w.uri})" }.to_a.join("\n") + "\n\n" +
             _('%{world_class}#uri を定義することでこのエラーを回避できます。詳しくは %{see} を参照してください') % {world_class: new.class, see: 'https://dev.mikutter.hachune.net/issues/1231'}
  end

  # 現在選択されているアカウントを返す
  # ==== Return
  # [Diva::Model] カレントアカウント
  def current_world
    @current ||= Plugin.collect(:worlds).first
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
    raise Plugin::CurrentWorld::WorldNotfoundError unless Plugin.collect(:worlds).include?(new)
    @current = new
  end

end
