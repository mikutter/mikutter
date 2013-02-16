# -*- coding: utf-8 -*-
# プラグインを全てロードする
miquire :core, 'plugin'

Miquire::Plugin.loadpath << 'plugin' << '../plugin' << File.join(Environment::CONFROOT, 'plugin')
spec_unsupported = []
Miquire::Plugin.each{ |path|
  spec_filename = File.join(File.dirname(path), "spec")
  if FileTest.exist? spec_filename
    spec = YAML.load_file(spec_filename).symbolize
    Plugin.load_file(path, spec) if Mopt.plugin.empty? or Mopt.plugin.include?(spec[:slug].to_s)
  else
    spec_unsupported << [ path,
                          { name: File.basename(path),
                            slug: File.basename(path).to_sym }] end }
spec_unsupported.each{ |args|
  Plugin.load_file(*args) if Mopt.plugin.empty? or Mopt.plugin.include?(args[1][:slug])
}
