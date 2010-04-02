
miquire :plugin, 'plugin'

module Addon
  class Addon < Plugin::Plugin

    def regist_tab(watch, container, label, image=nil)
      #Plugin::GUI.instance.regist_tab(container, label)
      Plugin::Ring::fire(:plugincall, [:gui, watch, :mui_tab_regist, container, label,
                                       (image and Gtk::WebIcon.new(image, 24, 24))])
    end

  end
end

miquire :addon
