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
      if stream == $stdin
        print 'MIKU >'
        $stdout.flush end
      begin
        puts MIKU.unparse(miku(MIKU.parse(stream), scope))
      rescue MIKU::MikuException => e
        puts e.to_s
      end
    end
  end
end
