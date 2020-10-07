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
    %<"#{v}">
  else
    v
  end
end

writer = -> (spec) do
  depends = Miquire::Plugin.depended_plugins(spec)
  if (depends || []).empty?
    puts "  #{escape.(spec[:slug])};"
  else
    depends.each do |depend|
      puts "  #{escape.(spec[:slug])} -> #{escape.(depend[:slug])};"
    end
  end
end

puts 'digraph mikutter_plugin {'

if Array(Mopt.plugin).empty?
  Miquire::Plugin.each_spec(&writer)
else
  available = Array(Mopt.plugin).inject(Set.new(Array(Mopt.plugin))) do |depends, depend_slug|
    Miquire::Plugin.depended_plugins(depend_slug, recursive: true).each do |spec|
      depends << spec[:slug]
    end
  end
  available.map{|x| x.to_spec }.each(&writer)
end

puts '}'
