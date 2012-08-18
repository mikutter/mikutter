# -*- coding: utf-8 -*-

require File.expand_path File.join(File.dirname(__FILE__), 'pane')
require File.expand_path File.join(File.dirname(__FILE__), 'cuscadable')
require File.expand_path File.join(File.dirname(__FILE__), 'hierarchy_child')
require File.expand_path File.join(File.dirname(__FILE__), 'tab')
require File.expand_path File.join(File.dirname(__FILE__), 'widget')

class Plugin::GUI::Timeline

  include Plugin::GUI::Cuscadable
  include Plugin::GUI::HierarchyChild
  include Plugin::GUI::HierarchyParent
  include Plugin::GUI::Widget

  role :timeline

  def initialize(slug, name)
    super
    Plugin.call(:timeline_created, self)
  end

  alias __set_parent_timeline__ set_parent
  def set_parent(tab)
    Plugin.call(:gui_timeline_join_tab, self, tab)
    __set_parent_timeline__(tab)
  end

  def <<(messages)
    messages = Messages.new(messages) if messages.is_a? Enumerable
    Plugin.call(:gui_timeline_add_messages, self, messages)
  rescue TypedArray::UnexpectedTypeException => e
    error "type mismatch!"
    raise e
  end

  # このタイムラインをアクティブにする。また、子のPostboxは非アクティブにする
  # ==== Return
  # self
  def active!
    @active_child = false
    set_active_child(nil)
    super end

  # 選択されているMessageを返す
  # ==== Return
  # 選択されているMessage
  def selected_messages
    messages = Plugin.filtering(:gui_timeline_selected_messages, self, [])
    messages[1] if messages.is_a? Array end

  # _in_reply_to_message_ に対するリプライを入力するPostboxを作成してタイムライン上に表示する
  # ==== Args
  # [in_reply_to_message] リプライ先のツイート
  # [options] Postboxのオプション
  def create_reply_postbox(in_reply_to_message, options = {})
    i_postbox = Plugin::GUI::Postbox.instance
    i_postbox.options = options
    i_postbox.poster = in_reply_to_message
    self << i_postbox
  end

  # Postboxを作成してこの中に入れる
  # ==== Args
  # [options] 設定値
  # ==== Return
  # 新しく作成したPostbox
  def postbox(options = {})
    postbox = Plugin::GUI::Postbox.instance
    postbox.options = options
    self << postbox
    postbox
  end

  # このタイムライン内の _message_ の部分文字列が選択されている場合それを返す。
  # 何も選択されていない場合はnilを返す
  # ==== Args
  # [message] 調べるMessageのインスタンス
  # ==== Return
  # 選択されたテキスト
  def selected_text(message)
    type_strict message => Message
    result = Plugin.filtering(:gui_timeline_selected_text, self, message, nil)
    result.last if result end

end
