# -*- coding: utf-8 -*-

require 'test/unit'
require 'rubygems'
require 'mocha' # !> already initialized constant AssertionFailedError
require File.expand_path(File.dirname(__FILE__)+'/../helper')
# require File.expand_path(File.dirname(__FILE__) + '/../miquire')
# require File.expand_path(File.dirname(__FILE__) + '/../lib/test_unit_extensions')

$debug = true
$logfile = nil
$daemon = false

Dir::chdir File.dirname(__FILE__) + '/../core'

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

  must "get plugin slug by path (spec exist)" do
    assert_equal(:rest, Miquire::Plugin.get_slug(File.expand_path(File.join(File.dirname(__FILE__), '../../core/plugin/rest/'))))
  end

  must "get plugin slug by path (spec not exist)" do
    Miquire::Plugin.stubs(:get_spec).returns(false)
    assert_equal(:rest, Miquire::Plugin.get_slug(File.expand_path(File.join(File.dirname(__FILE__), '../../core/plugin/rest/'))))
    assert_equal(:rest, Miquire::Plugin.get_slug(File.expand_path(File.join(File.dirname(__FILE__), '../../core/plugin/rest/rest.rb'))))
  end

  must "to_hash plugin slug and path" do
    p Miquire::Plugin.to_hash
  end

  must "load a plugin and depends" do
    #Miquire::Plugin.load(:home_timeline)
  end

end
