# -*- coding: utf-8 -*-

require 'test/unit'
require 'rubygems'
require 'mocha'
require 'pp'
listener = File.expand_path File.join(File.dirname(__FILE__), 'listener')
require File.expand_path(File.dirname(__FILE__) + '/../../utils')
miquire :lib, 'test_unit_extensions'

class Plugin; end
class Plugin::Setting; end
class UserConfig; end
require listener

class TC_Listener < Test::Unit::TestCase
  must "no value given" do
    n = Plugin::Setting::Listener.new
    n.set :a
    assert_equal(:a, n.get)
  end

  must "set hooked" do
    x = nil
    n = Plugin::Setting::Listener.new :set => lambda{ |new| x = new }
    n.set :a
    assert_equal(:a, n.get)
    assert_equal(:a, x)
  end

  must "get hooked" do
    x = nil
    n = Plugin::Setting::Listener.new :get => lambda{ x }
    assert_nil(n.get)
    x = :a
    assert_equal(:a, n.get)
    n.set :b
    assert_equal(:a, n.get)
  end

  must "between hooked" do
    x = nil
    n = Plugin::Setting::Listener.new(:set => lambda{ |new| x = new },
                                      :get => lambda{ x })
    assert_nil(n.get)
    x = :a
    assert_equal(:a, n.get)
    n.set :b
    assert_equal(:b, n.get)
  end

  must "slash" do
    UserConfig.stubs(:[]).with(:setting_test).returns(HYDE).once
    UserConfig.stubs(:[]=).with(:setting_test, HYDE).returns(HYDE).once
    assert_equal(156, Plugin::Setting::Listener[:setting_test].get)
    assert_equal(156, Plugin::Setting::Listener[:setting_test].set(HYDE))
  end

end
# >> Loaded suite -
# >> Started
# >> .....
# >> Finished in 0.001353 seconds.
# >> 
# >> 5 tests, 13 assertions, 0 failures, 0 errors, 0 skips
# >> 
# >> Test run options: --seed 49676
