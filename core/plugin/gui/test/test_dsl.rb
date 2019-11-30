# -*- coding: utf-8 -*-

# class Plugin
#   module GUI; end end

require 'test/unit'
Dir::chdir __dir__ + '/../../../'
require File.expand_path(__dir__ + '/lib/test_unit_extensions')
require File.expand_path(__dir__ + '/utils')
require File.expand_path(__dir__ + '/plugin')
require File.expand_path(__dir__ + '/plugin/gui/gui')

class TC_PluginGUIDSL < Test::Unit::TestCase

  def setup
  end

  must "can initialize tab" do
	Plugin.create :home_timeline do
      tab :home_timeline, "Home Timeline" do
        timeline :home_timeline end end
  end

end
# ~> /usr/lib/ruby/1.9.1/rubygems/custom_require.rb:36:in `require': cannot load such file -- /home/toshi/Documents/hobby/utils (LoadError)
# ~> 	from /usr/lib/ruby/1.9.1/rubygems/custom_require.rb:36:in `require'
# ~> 	from -:9:in `<main>'
