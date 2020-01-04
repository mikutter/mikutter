# -*- coding: utf-8 -*-
# プラグインを全てロードする
require 'miquire_plugin'

Environment::PLUGIN_PATH.each do |path|
  Miquire::Plugin.loadpath << path
end
Miquire::Plugin.loadpath << File.join(Environment::CONFROOT, 'plugin')

if Mopt.plugin.is_a? Array
  ['core', *Mopt.plugin].uniq.each(&Miquire::Plugin.method(:load))
else
  Miquire::Plugin.load_all
end

