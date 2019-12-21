# -*- coding: utf-8 -*-
# ツイート投稿ウィジェット

require_relative 'cuscadable'
require_relative 'hierarchy_child'
require_relative 'window'
require_relative 'timeline'
require_relative 'widget'

class Plugin::GUI::Postbox

  module PostboxParent; end

  include Plugin::GUI::Cuscadable
  include Plugin::GUI::HierarchyChild
  include Plugin::GUI::Widget

  role :postbox

  set_parent_event :gui_postbox_join_widget

  set_parent_class Plugin::GUI::Postbox::PostboxParent

  attr_accessor :options

  class << self
    # Postboxは、他のウィジェットと違ってキー入力中に他のロールに対するmikutterコマンドを実行すべきでない。
    # なので、find_role_ancestorは常に _find_ がPostboxの時だけ有効な値を返す
    # ==== Args
    # [find] 探すロール
    # ==== Return
    # findがPlugin::GUI::Postboxならそれを、それ以外ならnil
    def find_role_ancestor(find)
      self if role == find end
  end

  def initialize(*args)
    super
    @options = {}
    Plugin.call(:postbox_created, self) end

  # このPostboxの内容を投稿する
  # ==== Args
  # [world:] 投稿先のWorld。nilを与えた場合は自動選択。
  # ==== Return
  # self
  def post_it!(world: nil)
    Plugin.call(:gui_postbox_post, self, {world: world})
    self
  end

  # このPostboxがユーザの入力を受け付けているなら真。
  # 偽を返すPostboxは、投稿処理中か、投稿が完了して破棄されたもの
  # ==== Return
  # 編集中なら真
  def editable?
    editable = Plugin.filtering(:gui_postbox_input_editable, self, false)
    editable.last if editable end

end

class Plugin::GUI::Window
  include Plugin::GUI::Postbox::PostboxParent end

class Plugin::GUI::Timeline
  include Plugin::GUI::Postbox::PostboxParent end
