# -*- coding: utf-8 -*-
# ruby

require_relative 'array'

def yamlisp(node)
  if(node.is_a? YamLisp::Node) then
    node.yamlisp_eval
  else
    node
  end
end
