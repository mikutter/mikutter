# -*- coding: utf-8 -*-

require 'gtk2'
miquire :mui, 'extension'

=begin rdoc
  オブジェクトに、アクティブ状態を管理する機能を与える。
  オブジェクトはいくつでもアクティブにできるし、状態が変わったときにフックしたり、アクティブなものを取得したりもできる。
=end
module Gtk::MumbleSelect

  def self.included(includer)
    includer.extend(Selection)
  end

  # このメッセージを選択状態にする。
  # _append_ がtrueなら、既に選択されているものをクリアせず、自分の選択状態を反転する。
  # 最終的にアクティブになったかどうかを返す
  def active(append = false)
    mainthread_only
    if append
      if active?
        inactive
        false
      else
        self.class.set_active_mumble(self)
        true end
    else
      if not active?
        self.class.reset_active_mumbles([self]) end
      true end end

  # このメッセージが選択状態ならtrueを返す
  def active?
    self.class.get_active_mumbles.include?(self) end

  # 選択状態を解除する
  def inactive
    self.class.delete_active_mumble(self)
    false end

  # 選択されたときに呼ばれるメソッド
  def activate
  end

  # 選択解除されたときに呼ばれるメソッド
  def inactivate
  end

  module Selection
    # アクティブなオブジェクトを配列で返す。
    # 先頭のものほど最後に追加されたもの
    def get_active_mumbles
      active_mumbles.dup end

    # objを選択スタックに詰む。通常はこちらではなく、 Gtk::MumbleSelect#active を使うこと
    def set_active_mumble(obj)
      active_mumbles.unshift(obj)
      obj.activate end

    # objをスタックから削除する。通常はこちらではなく、 Gtk::MumbleSelect#inactive を使うこと
    def delete_active_mumble(obj)
      active_mumbles.delete(obj)
      obj.inactivate end

    # 全ての選択を解除し、キューを _default_ と同じ状態にする
    def reset_active_mumbles(default = [])
      type_strict default => :to_a
      active_mumbles.each{ |x| x.inactive }
      @active_mumbles = default.dup.to_a
      default.each{ |x| x.activate } end
    alias inactive reset_active_mumbles

    private
    def active_mumbles
      @active_mumbles ||= [] end
  end

end
