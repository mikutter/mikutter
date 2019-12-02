# -*- coding: utf-8 -*-
# 全プラグインにpot作成

require 'boot/delayer'
require "miquire_plugin"

require 'gettext/tools/task'
require 'rake'

mo_root = File.join(CHIConfig::CACHE, "uitranslator", "locale")

Miquire::Plugin.loadpath << Environment::PLUGIN_PATH << File.join(__dir__, "..", "..", "plugin") << File.join(Environment::CONFROOT, 'plugin')

enable_plugins = ARGV[1,]
failed_plugins = []

Miquire::Plugin.each_spec do |spec|
  if (enable_plugins.empty? or enable_plugins.include? spec[:slug].to_s) and
      (defined?(spec[:depends][:plugin]) and spec[:depends][:plugin].include? "uitranslator")
    po_root = File.join spec[:path], "po"
    begin
      GetText::Tools::Task.define do |task|
        task.spec = Gem::Specification.new do |s|
          s.name = spec[:slug].to_s
          s.version = spec[:version].to_s
          s.files = Dir.glob("#{spec[:path]}/**/*.rb")
        end
        task.locales = ["ja"]
        task.po_base_directory = po_root
      end
    rescue Exception => e
      failed_plugins << spec[:slug]
    end
  end
end
notice Rake::Task.tasks.join("\n")

# gettext:po:updateがいちいち翻訳者名とか聞いてきてうざいので潰す。
# 本来はgettextにパッチを送るとかするべきな気がする。
class GetText::Tools::MsgInit
  def translator_full_name
    ""
  end

  def translator_mail
    ""
  end
end

Rake::Task["gettext:pot:create"].invoke
Rake::Task["gettext:po:update"].invoke

puts "failed plugins: #{failed_plugins}" unless failed_plugins.empty?
