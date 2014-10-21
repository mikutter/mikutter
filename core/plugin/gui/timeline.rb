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

  set_parent_event :gui_timeline_join_tab

  def initialize(*args)
    super
    Plugin.call(:timeline_created, self)
  end

  def <<(messages)
    if messages.is_a? Enumerable
      messages = Messages.new(messages)
    else
      messages = Messages.new([messages]) end
    Plugin.call(:gui_timeline_add_messages, self, messages)
  rescue TypedArray::UnexpectedTypeException => e
    error "type mismatch!"
    raise e
  end

  # タイムラインの中のツイートを全て削除する
  def clear
    Plugin.call(:gui_timeline_clear, self) end

  # タイムラインの一番上にスクロール
  def scroll_to_top
    Plugin.call(:gui_timeline_scroll_to_top, self) end

  # このタイムラインをアクティブにする。また、子のPostboxは非アクティブにする
  # ==== Return
  # self
  def active!(just_this=true, by_toolkit=false)
    set_active_child(nil, by_toolkit) if just_this
    super end

  # タイムラインに _messages_ が含まれているなら真を返す
  # ==== Args
  # [*messages] Message タイムラインに含まれているか確認するMessageオブジェクト。配列や引数で複数指定した場合は、それら全てが含まれているかを返す
  # ==== Return
  # _messages_ が含まれているなら真
  def include?(*messages)
    args = Messages.new([messages].flatten).freeze
    detected = Plugin.filtering(:gui_timeline_has_messages, self, args)
    detected.is_a? Array and detected[1].size == args.size end

  # _messages_ のうち、Timelineに含まれているMessageを返す
  # ==== Args
  # [*messages] Message タイムラインに含まれているか確認するMessageオブジェクト
  # ==== Return
  # _messages_ で指定された中で、selfに含まれるもの
  def in_message(*messages)
    args = Messages.new([messages].flatten).freeze
    detected = Plugin.filtering(:gui_timeline_has_messages, self, args)
    if detected.is_a? Array
      Messages.new(detected[1])
    else
      Messages.new([]) end end

  # _messages_ のうち、Timelineに含まれていないMessageを返す
  # ==== Args
  # [*messages] Message タイムラインに含まれているか確認するMessageオブジェクト
  # ==== Return
  # _messages_ で指定された中で、selfに含まれていないもの
  def not_in_message(*messages)
    Messages.new([messages].flatten - in_message(messages)) end

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
    notice "created postbox: #{i_postbox.inspect}"
    self.add_child i_postbox
  end

  # Postboxを作成してこの中に入れる
  # ==== Args
  # [options] 設定値
  # ==== Return
  # 新しく作成したPostbox
  def postbox(options = {})
    postbox = Plugin::GUI::Postbox.instance
    postbox.options = options
    self.add_child postbox
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

  # Messageを並べる順序を数値で返すブロックを設定する
  # ==== Args
  # [&block] 並び順
  # ==== Return
  # self
  def order(&block)
    Plugin.call(:gui_timeline_set_order, self, block)
  end

end
