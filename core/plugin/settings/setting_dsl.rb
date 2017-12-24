# -*- coding: utf-8 -*-

module Plugin::Settings; end

require_relative 'listener'

miquire :mui, 'form_dsl', 'form_dsl_select', 'form_dsl_multi_select'

require 'gtk2'

=begin rdoc
プラグインに、簡単に設定ファイルを定義する機能を提供する。
以下の例は、このクラスを利用してプラグインの設定画面を定義する例。
  Plugin.create(:test) do
    settings("設定") do
      boolean "チェックする", :test_check
    end
  end

settingsの中身は、 Plugin::Settings のインスタンスの中で実行される。
つまり、 Plugin::Settings のインスタンスメソッドは、 _settings{}_ の中で実行できるメソッドと同じです。
例ではbooleanメソッドを呼び出して、真偽値を入力させるウィジェットを配置させるように定義している
(チェックボックス)。明確にウィジェットを設定できるわけではなくて、値の意味を定義するだけなので、
前後関係などに影響されてウィジェットが変わる場合があるかも。
=end
class Plugin::Settings::SettingDSL < Gtk::VBox
  include Gtk::FormDSL

  def create_inner_setting
    self.class.new(@plugin)
  end

  def initialize(plugin)
    type_strict plugin => Plugin
    @plugin = plugin
    super()
  end

  def [](key)
    Plugin::Settings::Listener[key].get
  end

  def []=(key, value)
    Plugin::Settings::Listener[key].set(value)
  end

end
