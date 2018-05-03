# -*- coding: utf-8 -*-

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
    begin
      if self.current_world != new
        self.current_world = new
        Plugin.call(:primary_service_changed, current_world)
      end
    rescue RuntimeError => err
      error err
    end
  end

  # 現在選択されているアカウントを返す
  # ==== Return
  # [Diva::Model] カレントアカウント
  def current_world
    @current ||= Enumerator.new{|y| Plugin.filtering(:worlds, y) }.first
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
    raise RuntimeError unless Enumerator.new{|y| Plugin.filtering(:worlds, y) }.include?(new)
    @current = new
  end

end
