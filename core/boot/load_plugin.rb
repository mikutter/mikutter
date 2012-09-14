# -*- coding: utf-8 -*-
# プラグインを全てロードする
miquire :core, 'plugin'
miquire :addon, 'addon'

Miquire::Plugin.loadpath << 'plugin' << '../plugin' << '~/.mikutter/plugin'
Miquire::Plugin.each{ |path| require path }
