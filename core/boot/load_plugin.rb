# -*- coding: utf-8 -*-
# プラグインを全てロードする
miquire :core, 'plugin'

Miquire::Plugin.loadpath << 'plugin' << '../plugin' << '~/.mikutter/plugin'
spec_unsupported = []
Miquire::Plugin.each{ |path|
  spec_filename = File.join(File.dirname(path), "spec")
  if FileTest.exist? spec_filename
    spec = YAML.load_file(spec_filename).symbolize
    Plugin.load_file(path, spec)
  else
    spec_unsupported << [ path,
                          { name: File.basename(path),
                            slug: File.basename(path).to_sym }] end }
spec_unsupported.each{ |args|
  Plugin.load_file(*args) }
