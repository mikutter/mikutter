# -*- coding: utf-8 -*-

require 'boot/delayer'
require 'miquire_plugin'

using Miquire::ToSpec

Environment::PLUGIN_PATH.each do |path|
  Miquire::Plugin.loadpath << path
end
Miquire::Plugin.loadpath << File.join(Environment::CONFROOT, 'plugin')

escape = -> (v) do
  if /[^\w]/.match?(v)
    '"%{v}"' % { v: v.gsub('"', '\"') }
  else
    v
  end
end

writer = -> (node, graph, spec) do
  depends = Miquire::Plugin.depended_plugins(spec)
  if (depends || []).empty?
    graph.puts "  #{escape.(spec[:slug])};"
  else
    depends.zip(Array(spec.dig(:depends, :plugin))).each do |depend, src|
      if depend
        graph.puts "  #{escape.(spec[:slug])} -> #{escape.(depend[:slug])};"
      else
        id = src.hash
        node.puts "  #{id} [label = #{escape.(src.inspect)}, shape = box, fillcolor = \"#FFCCCC\", style = \"solid,filled\"];"
        graph.puts "  #{escape.(spec[:slug])} -> #{id};"
      end
    end
  end
end

puts 'digraph mikutter_plugin {'

graph_buf = StringIO.new('', 'r+')

if Array(Mopt.plugin).empty?
  Miquire::Plugin.each_spec(&writer.curry.(STDOUT, graph_buf))
else
  available = Array(Mopt.plugin).inject(Set.new(Array(Mopt.plugin))) do |depends, depend_slug|
    Miquire::Plugin.depended_plugins(depend_slug, recursive: true).each do |spec|
      depends << spec[:slug]
    end
  end
  available.map{|x| x.to_spec }.each(&writer.curry.(STDOUT, graph_buf))
end

graph_buf.rewind
STDOUT.write graph_buf.read

puts '}'
