# -*- coding: utf-8 -*-

require 'test/unit'
require 'rubygems'
require 'mocha' # !> already initialized constant AssertionFailedError
require File.expand_path(File.dirname(__FILE__) + '/../miquire')
require File.expand_path(File.dirname(__FILE__) + '/../lib/test_unit_extensions')

$debug = true
$logfile = nil
$daemon = false

Dir::chdir File.dirname(__FILE__) + '/../'

class TC_Miquire < Test::Unit::TestCase
  def setup
  end

  must "miquire lib" do
    Miquire.stubs(:miquire_original_require).with('library').returns(true).once

    miquire :lib, 'library'
  end

  must "miquire normal" do
    Miquire.stubs(:miquire_original_require).with('normal/normal_file').returns(true).once

    miquire :normal, 'normal_file'
  end

  must "miquire allfiles" do
    files = stub()
    files.stubs(:select).returns(["file1", "file2", "file3"])
    Dir.stubs(:glob).with('allfiles/*').returns(files).once

    Miquire.stubs(:miquire_original_require).with('file1').returns(true).once
    Miquire.stubs(:miquire_original_require).with('file2').returns(true).once
    Miquire.stubs(:miquire_original_require).with('file3').returns(true).once

    miquire :allfiles
  end

  must "enum plugins" do
    Miquire::Plugin.loadpath << 'addon/'
    p Miquire::Plugin.to_a
  end

end
# >> Loaded suite -
# >> Started
# >> "/home/toshi/Documents/hobby/scripts/mikutter/trunk/core/addon/*.rb"
# >> ["/home/toshi/Documents/hobby/scripts/mikutter/trunk/core/addon/change_account.rb", "/home/toshi/Documents/hobby/scripts/mikutter/trunk/core/addon/settings.rb", "/home/toshi/Documents/hobby/scripts/mikutter/trunk/core/addon/shortcutkey.rb", "/home/toshi/Documents/hobby/scripts/mikutter/trunk/core/addon/search.rb", "/home/toshi/Documents/hobby/scripts/mikutter/trunk/core/addon/followingcontrol.rb", "/home/toshi/Documents/hobby/scripts/mikutter/trunk/core/addon/set_view.rb", "/home/toshi/Documents/hobby/scripts/mikutter/trunk/core/addon/contextmenu.rb", "/home/toshi/Documents/hobby/scripts/mikutter/trunk/core/addon/mentions.rb", "/home/toshi/Documents/hobby/scripts/mikutter/trunk/core/addon/friend_timeline.rb", "/home/toshi/Documents/hobby/scripts/mikutter/trunk/core/addon/addon.rb", "/home/toshi/Documents/hobby/scripts/mikutter/trunk/core/addon/streaming.rb", "/home/toshi/Documents/hobby/scripts/mikutter/trunk/core/addon/extract.rb", "/home/toshi/Documents/hobby/scripts/mikutter/trunk/core/addon/profile.rb", "/home/toshi/Documents/hobby/scripts/mikutter/trunk/core/addon/notify.rb", "/home/toshi/Documents/hobby/scripts/mikutter/trunk/core/addon/bugreport.rb", "/home/toshi/Documents/hobby/scripts/mikutter/trunk/core/addon/smartthread.rb", "/home/toshi/Documents/hobby/scripts/mikutter/trunk/core/addon/list.rb", "/home/toshi/Documents/hobby/scripts/mikutter/trunk/core/addon/set_input.rb"]
# >> ....
# >> Finished in 0.002515 seconds.
# >> 
# >> 4 tests, 6 assertions, 0 failures, 0 errors
