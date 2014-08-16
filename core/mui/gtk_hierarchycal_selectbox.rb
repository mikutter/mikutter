# -*- coding: utf-8 -*-

require 'gtk2'
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'utils'))
miquire :mui, 'selectbox'

=begin rdoc
  複数選択ウィジェットを作成する。
  これで作成されたウィジェットは、チェックボックスで複数の項目が選択できる。
  各項目は文字列でしか指定できない。
  項目名に/が入っていると階層化される
=end

class Gtk::HierarchycalSelectBox < Gtk::SelectBox
  DELIMITER = '/'.freeze

  private
  def initialize_model
    set_model(Gtk::TreeStore.new(*column_schemer.flatten.map{|x| x[:type]}))
  end

  def setting_values(values, selected)
    parent_node = {}            # name => TreeIter
    parent_node_list(values.map(&:last)).each do |name, parent|
      iter = parent_node[name] = model.append(parent_node[parent])
      iter[ITER_ID] = -1
      iter[ITER_STRING] = child_name(name) end
    values.reject{|_,name| parent_node.include? name}.each{ |pair|
      id, string = *pair
      iter = model.append(parent_node[parent_name(string)])
      iter[ITER_ID] = id
      iter[ITER_STRING] = child_name(string)
      iter[ITER_CHECK] = (selected and @selected.include?(id)) } end

  # /区切りの文字列からなる配列を受け取って、各要素の最後の/の前の値を返す
  # /が含まれていない文字列に関しては、それを取り除く。
  # 戻り値は、より親のノードが要素の先に存在することを保証する。
  # ==== Args
  # [namelist] Array 文字列の配列
  # ==== Return
  # Array 親の名前のリスト
  def parent_node_list(namelist)
    namelist.lazy.select{|_|
      _.include? DELIMITER
    }.map(&method(:parent_name)).sort_by{ |node|
      [node.count(DELIMITER), namelist.index{|n| n.start_with? node}||0] }.uniq end

  # /で区切られた文字列の最後を除いた要素を取得する
  # ==== Args
  # [path] String /区切りの文字列
  # ==== Return
  # String
  def parent_name(path)
    path.split(DELIMITER)[0..-2].join(DELIMITER) end

  # /で区切られた文字列の最後の要素を取得する
  # ==== Args
  # [path] String /区切りの文字列
  # ==== Return
  # String
  def child_name(path)
    path.split(DELIMITER)[-1] end

end
