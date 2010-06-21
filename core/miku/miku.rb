#! /usr/bin/ruby

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
    stream = if ARGV.last then open(ARGV.last, 'r') else $stdin end
    scope = MIKU::SymbolTable.new
    while(not stream.eof?) do
      print 'MIKU >' if stream == $stdin
      begin
        puts MIKU.unparse(miku(MIKU.parse(stream), scope))
      rescue MIKU::EndofFile
      end
    end
  end
end
