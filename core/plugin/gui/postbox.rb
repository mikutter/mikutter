# -*- coding: utf-8 -*-
# ツイート投稿ウィジェット

require File.expand_path File.join(File.dirname(__FILE__), 'cuscadable')
require File.expand_path File.join(File.dirname(__FILE__), 'hierarchy_child')
require File.expand_path File.join(File.dirname(__FILE__), 'window')
require File.expand_path File.join(File.dirname(__FILE__), 'timeline')
require File.expand_path File.join(File.dirname(__FILE__), 'widget')

class Plugin::GUI::Postbox

  module PostboxParent; end

  include Plugin::GUI::Cuscadable
  include Plugin::GUI::HierarchyChild
  include Plugin::GUI::Widget

  role :postbox

  set_parent_class Plugin::GUI::Postbox::PostboxParent

  attr_accessor :options, :poster

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

  def initialize(slug, name)
    super
    options = {}
    Plugin.call(:postbox_created, self) end

  alias __set_parent_postbox__ set_parent
  def set_parent(parent)
    Plugin.call(:gui_postbox_join_widget, self, parent)
    __set_parent_postbox__(parent)
  end

  # このPostboxの内容を投稿する
  # ==== Return
  # self
  def post_it!
    Plugin.call(:gui_postbox_post, self)
    self end

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
  include Plugin::GUI::HierarchyParent
  include Plugin::GUI::Postbox::PostboxParent end
