# -*- coding: utf-8 -*-
#! /usr/bin/ruby

if not defined? $loaded_miku
  $loaded_miku = true

  Dir.chdir(File.dirname(__FILE__)){
    require_relative 'array'
    require_relative 'hash'
    require_relative 'symbol'
    require_relative 'symboltable'
    require_relative 'nil'
    require_relative 'parser'
  }

  def miku(node, scope=MIKU::SymbolTable.new)
    if(node.is_a? MIKU::Node) then
      begin
        node.miku_eval(scope)
      rescue MIKU::MikuException => e
        warn e
      rescue Exception => e
        warn "[MIKU Bug] fatal error on code #{node.inspect}"
        raise e
      end
    else
      node end end

  def miku_stream(stream, scope)
    begin
      while(not stream.eof?) do
        miku(MIKU.parse(stream), scope) end
    rescue MIKU::EndofFile
    rescue MIKU::MikuException => e
      warn e end end

  if(__FILE__ == $0) then
    scope = MIKU::SymbolTable.new.run_init_script
    if ARGV.last
      miku_stream(open(ARGV.last, 'r'), scope)
    else
      require_relative 'readline'
      while buf = Readline.readline('>>> ', true)
        begin
          puts MIKU.unparse(miku(MIKU.parse(buf), scope))
        rescue MIKU::MikuException => e
          puts e.to_s end end end end end
