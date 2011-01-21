# -*- coding: utf-8 -*-
miquire :mui, 'extension'

require 'gtk2'

class Gtk::Box
  def insert_child(child, index)
    front = self.children[0, index]
    front.each{|w|
      self.remove(w)
    }
    self.__send__(self.insert_func, child, false)
    front.reverse.each{|w|
      self.__send__(self.insert_func, w, false)
    }
  end
end

# 順番が決っているVBox。新たにいれた要素は全て予めきめられた順番で並ぶように適切な場所に入れられる。
class Gtk::PriorityVBox < Gtk::VBox
  protected :pack_start, :pack_end, :reorder_child

  attr_accessor :insert_func

  # ブロックとして、順番を決定するためのProcオブジェクトを渡す。
  # 各Gtk::Widgetオブジェクトを引数に取り、<=>演算子を実装しているオブジェクトを返す。
  # 引数を二つ取る場合は、第二引数にこのインスタンスが渡される。
  def initialize(*args, &proc)
    super(*args)
    @priority = if proc.arity == 1
                  lambda{ |x| yield x }
                else
                  lambda{ |x| yield x, self }
                end
    @insert_func = :pack_end
  end

  def pack(child, expand = true, fill = true, padding = 0)
    mainthread_only
    return if self.destroyed?
    priority = @priority.call(child)
    if pos = insert_position(priority)
      insert_child(child, pos) end
    self end

  def pack_all(children, expand = true, fill = true, padding = 0)
    return if self.destroyed?
    children.sort_by{ |c| @priority.call(c) }.reverse_each{ |c|
      self.pack(c, expand, fill, padding) }
    self end

  def reorder(widget)
    priority = @priority.call(widget)
    if pos = insert_position(priority)
      reorder_child(widget, children.size - pos) end
    self end

  private

  def position(widget)
    children.find_index(&widget.method(:==)) end

  # widgetを挿入するindexを返す。全く等価なものがあった場合はそのindexを返す
  def insert_position_widget(widget)
    insert_position(@priority.call(widget)) end

  # 挿入するindexを返す。全く等価なものがあった場合はそのindexを返す。引数には、優先順位を渡す
  def insert_position(priority)
    priorities.each_with_index{|prio, index|
      if (prio <=> priority) < 0
        return index
      elsif (prio <=> priority) == 0
        return nil end }
    self.children.size end

  # 優先順位の配列を返す
  def priorities
    children.map(&@priority) end

end
# ~> -:2: undefined method `miquire' for main:Object (NoMethodError)
