
miquire :plugin, 'plugin'

module Addon
  class Addon < Plugin::Plugin

    def regist_tab(watch, container, label)
      #Plugin::GUI.instance.regist_tab(container, label)
      Plugin::Ring::fire(:plugincall, [:gui, watch, :mui_tab_regist, container, label])
    end

  end
end

miquire :addon
