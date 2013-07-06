# -*- coding: utf-8 -*-
# 全プラグインにpot作成

miquire :core, "miquire_plugin"
require 'gettext/tools'

mo_root = File.join(CHIConfig::CACHE, "uitranslator", "locale")

Miquire::Plugin.loadpath << Environment::PLUGIN_PATH << File.join(File.dirname(__FILE__), "..", "..", "plugin") << File.join(Environment::CONFROOT, 'plugin')

enable_plugins = ARGV[1,]
failed_plugins = []

Miquire::Plugin.each_spec do |spec|
  if (enable_plugins.empty? or enable_plugins.include? spec[:slug].to_s) and
      (defined?(spec[:depends][:plugin]) and spec[:depends][:plugin].include? "uitranslator")
    po_root = File.join spec[:path], "po"
    begin
      GetText.update_pofiles(spec[:slug].to_s,
                             Dir.glob("#{spec[:path]}/**/*.rb"),
                             "#{spec[:slug]} #{spec[:version]}",
                             po_root: po_root)
    rescue Exception => e
      failed_plugins << spec[:slug]
    end
  end
end

puts "failed plugins: #{failed_plugins}" unless failed_plugins.empty?
