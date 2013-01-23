# -*- coding: utf-8 -*-

require 'test/unit'
require 'rubygems'
require 'mocha'
require File.expand_path(File.dirname(__FILE__) + '/../../helper')

Dir.chdir(File.expand_path(File.dirname(__FILE__) + '/../../core'))
$LOAD_PATH.push '.'
require 'utils'

miquire :lib, 'test_unit_extensions'
miquire :lib, 'instance_storage'

class TC_InstanceStorage < Test::Unit::TestCase
  def setup
  end

  must "get and create instance" do
    klass = Class.new do
      include InstanceStorage end
    assert_same(klass[:foo], klass[:foo])
    assert_not_same(klass[:foo], klass[:bar])
  end

  must "get all instances" do
    klass = Class.new do
      include InstanceStorage end
    assert_equal([], klass.instances)
    assert_equal([klass[:a], klass[:b]], klass.instances)
  end

  must "get all instances name" do
    klass = Class.new do
      include InstanceStorage end
    assert_equal([], klass.instances_name)
    klass[:a]
    klass[:b]
    assert_equal([:a, :b], klass.instances_name)
  end

  must "destroy instance" do
    klass = Class.new do
      include InstanceStorage end
    klass[:a]
    assert(klass.instance_exist? :a)
    klass.destroy(:a)
    assert(! klass.instance_exist?(:a))
  end

  must "get existing instance" do
    klass = Class.new do
      include InstanceStorage end
    assert_nil(klass.instance(:a))
    assert_equal(klass[:a], klass.instance(:a))
  end

end
