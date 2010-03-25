
miquire :plugin, 'plugin'

module Addon
  class Addon < Plugin::Plugin

    def regist_tab(container, label)
      Plugin::GUI.instance.regist_tab(container, label)
    end

  end
end

miquire :addon
