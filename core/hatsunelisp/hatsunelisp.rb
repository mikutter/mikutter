# ruby

Dir.chdir(File.dirname(__FILE__)){
  require 'array'
  require 'symbol'
  require 'symboltable'
  require 'nil'
  require 'parser'
}

def hatsunelisp(node, scope=HatsuneLisp::SymbolTable.new)
  if(node.is_a? HatsuneLisp::Node) then
    node.hatsunelisp_eval(scope)
  else
    node
  end
end

if(__FILE__ == $0) then
  scope = HatsuneLisp::SymbolTable.new
  loop{
    p scope
    print 'HatsuneLisp >'
    puts HatsuneLisp.unparse(hatsunelisp(HatsuneLisp.parse($stdin), scope))
  }
end
