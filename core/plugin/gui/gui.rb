# -*- coding: utf-8 -*-
# mikutterにGUIをつけるプラグイン

module Plugin::GUI; end

require File.expand_path File.join(File.dirname(__FILE__), 'tab')

Plugin.create :gui do

  filter_tabs do |set|
    [(set || {}).merge(Plugin::GUI::Tab.cuscaded)]
  end

end
