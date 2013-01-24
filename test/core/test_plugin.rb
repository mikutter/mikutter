# -*- coding: utf-8 -*-

require 'test/unit'
require 'rubygems'
require 'mocha'
require File.expand_path(File.dirname(__FILE__) + '/../helper')

miquire :core, 'plugin'

class TC_Plugin < Test::Unit::TestCase
  def setup
    Plugin.clear!
  end

  must "basic plugin" do
    sum = 0
    Plugin.create(:event) do
      on_increase do |v|
        sum += v end

      filter_increase do |v|
        [v * 2]
      end
    end
    Event[:increase].call(1)
    Delayer.run while not Delayer.empty?
    assert_equal(2, sum)
  end

  must "uninstall" do
    sum = 0
    Plugin.create(:event) do
      on_increase do |v|
        sum += v end
      filter_increase do |v|
        [v * 2]
      end
    end
    Plugin.create(:event).uninstall
    Event[:increase].call(1)
    Delayer.run while not Delayer.empty?
    assert_equal(0, sum)
  end

  must "detach" do
    sum = 0
    event = filter = nil
    Plugin.create(:event) do
      event = on_increase do |v|
        sum += v end
      filter = filter_increase do |v|
        [v * 2]
      end
    end
    Event[:increase].call(1)
    Delayer.run while not Delayer.empty?
    assert_equal(2, sum)

    Plugin.create(:event).detach filter
    Event[:increase].call(1)
    Delayer.run while not Delayer.empty?
    assert_equal(3, sum)

    Plugin.create(:event).detach event
    Event[:increase].call(1)
    Delayer.run while not Delayer.empty?
    assert_equal(3, sum)
  end

  must "get plugin list" do
    assert_equal([], Plugin.plugin_list)
    Plugin.create(:plugin_0)
    assert_equal([:plugin_0], Plugin.plugin_list)
    Plugin.create(:plugin_1)
    assert_equal([:plugin_0, :plugin_1], Plugin.plugin_list)
  end

  must "load exist plugin" do
    Plugin.stubs(:require).with("/path/to/plugin/loadtest/loadtest.rb").returns(true).once
    Plugin.load_file("/path/to/plugin/loadtest/loadtest.rb", slug: :loadtest)
  end

  must "load plugin dependencies" do
    Plugin.stubs(:require).with("a.rb").returns(true).once
    Plugin.stubs(:require).with("b.rb").returns(true).once
    Plugin.stubs(:require).with("c.rb").returns(true).once
    Plugin.load_file("a.rb", slug: :a, depends: {plugin: [:b, :c]})
    assert_equal([], Plugin.plugin_list)
    Plugin.load_file("b.rb", slug: :b)
    assert_equal([:b], Plugin.plugin_list)
    Plugin.load_file("c.rb", slug: :c)
    assert_equal([:b, :c, :a], Plugin.plugin_list)
  end

  must "dsl method defevent" do
    Plugin.create :defevent do
      defevent :increase, prototype: [Integer] end
    assert_equal([Integer], Event[:increase].options[:prototype])
    assert_equal(Plugin[:defevent], Event[:increase].options[:plugin])
  end

  must "unload hook" do
    value = 0
    Plugin.create(:unload) {
      on_unload {
        value += 2 }
      on_unload {
        value += 1 } }
    assert_equal(value, 0)
    Plugin.create(:unload).uninstall
    assert_equal(value, 3)
  end

end

