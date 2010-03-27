# ruby

require 'array'
require 'symbol'
require 'symboltable'
require 'parser'

def hatsunelisp(node)
  if(node.is_a? HatsuneLisp::Node) then
    node.hatsunelisp_eval
  else
    node
  end
end

if(__FILE__ == $0) then
  scope = HatsuneLisp::SymbolTable.new
  loop{
    print 'HatsuneLisp >'
    puts HatsuneLisp.parse($stdin).hatsunelisp_eval(scope).inspect
  }
end
