# -*- coding: utf-8 -*-

require 'gtk2'
require 'mui/gtk_selectbox'

=begin rdoc
  複数選択ウィジェットを作成する。
  これで作成されたウィジェットは、チェックボックスで複数の項目が選択できる。
  各項目は文字列でしか指定できない。
  項目名に/が入っていると階層化される
=end

class Gtk::HierarchycalSelectBox < Gtk::SelectBox

  private
  def initialize_model
    set_model(Gtk::TreeStore.new(*column_schemer.flatten.map{|x| x[:type]}))
  end

  def setting_values(values, selected)
    root_nodes = []
    values.each do |pair|
      id, name = *pair
      fullpath = []
      last_node = name.inject(nil) do |parent_node, hierarchy|
        fullpath << hierarchy
        if parent_node
          node = parent_node.n_children.times.lazy.map(&parent_node.method(:nth_child)).find{|_| _[ITER_STRING] == hierarchy } || model.append(parent_node)
        else
          node = root_nodes.find{|_| _[ITER_STRING] == hierarchy }
          if node.nil?
            node = model.append(nil)
            root_nodes << node end end
        node[ITER_ID] = @none
        node[ITER_STRING] = hierarchy
        node
      end
      last_node[ITER_ID] = id
      last_node[ITER_CHECK] = (selected and @selected.include?(id))
    end
  end

end
