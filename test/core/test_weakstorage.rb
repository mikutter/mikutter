# -*- coding: utf-8 -*-
require 'test/unit'
require 'rubygems'
require 'mocha'
require File.expand_path(File.dirname(__FILE__) + '/../helper')

Dir.chdir(File.expand_path(File.dirname(__FILE__) + '/../core'))
$LOAD_PATH.push '.'
require 'utils'

miquire :lib, 'test_unit_extensions', 'weakstorage'

class TC_WeakStorage < Test::Unit::TestCase
  def setup
  end

  must "size limited storage item insertion" do
    sls = SizeLimitedStorage.new(Symbol, String, 8)
    assert_equal(0, sls.using)
    sls[:a] = "foo"
    assert_equal("foo", sls[:a])
    assert_equal(3, sls.using)

    sls[:b] = "bar"
    assert_equal("foo", sls[:a])
    assert_equal("bar", sls[:b])
    assert_equal(6, sls.using)

    sls[:c] = "baz"
    assert_nil(sls[:a])
    assert_equal("bar", sls[:b])
    assert_equal("baz", sls[:c])
    assert_equal(6, sls.using)

    sls[:d] = "pi"
    assert_equal("bar", sls[:b])
    assert_equal("baz", sls[:c])
    assert_equal("pi", sls[:d])
    assert_equal(8, sls.using)

    assert(!sls.has_key?(:a))
    assert(sls.has_key?(:b))
    assert(sls.has_key?(:c))
    assert(sls.has_key?(:d))
    assert(!sls.has_key?(:e))
  end
end
