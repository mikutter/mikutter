# -*- coding: utf-8 -*-
# 全プラグインにpot作成

miquire :core, "miquire_plugin"
require 'gettext/tools'

mo_root = File.join(CHIConfig::CACHE, "uitranslator", "locale")

Miquire::Plugin.loadpath << Environment::PLUGIN_PATH << File.join(File.dirname(__FILE__), "..", "..", "plugin") << File.join(Environment::CONFROOT, 'plugin')

enable_plugins = ARGV[1,]

Miquire::Plugin.each_spec do |spec|
  if enable_plugins.empty? or enable_plugins.include? spec[:slug].to_s
    po_root = File.join spec[:path], "po"
    GetText.update_pofiles(spec[:slug].to_s,
                           Dir.glob("#{spec[:path]}/**/*.rb"),
                           "#{spec[:slug]} #{spec[:version]}",
                           po_root: po_root)
  end
end
