# /usr/bin/ruby

if not $loaded_miku
  $loaded_miku = true

  Dir.chdir(File.dirname(__FILE__)){
    require 'array'
    require 'symbol'
    require 'symboltable'
    require 'nil'
    require 'parser'
  }

  def miku(node, scope=MIKU::SymbolTable.new)
    if(node.is_a? MIKU::Node) then
      node.miku_eval(scope)
    else
      node
    end
  end

  if(__FILE__ == $0) then
    scope = MIKU::SymbolTable.new
    loop{
      p scope
      print 'MIKU >'
      puts MIKU.unparse(miku(MIKU.parse($stdin), scope))
    }
  end
end
