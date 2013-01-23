# -*- coding: utf-8 -*-
require 'test/unit'
require 'rubygems'
require 'mocha'
require File.expand_path(File.dirname(__FILE__) + '/../../core/utils')
miquire :core, 'messageconverters'
miquire :lib, 'weakstorage'

$debug = true
$logfile = nil
$daemon = false

class Plugin
end

class TC_MessageConverters < Test::Unit::TestCase
  # include FlexMock::TestCase

  def setup
  end

  def test_shrink
    Plugin.stubs(:filtering).with(:shrink_url, 'http://google.jp/').returns(['http://ha2.ne/156'])
    Plugin.stubs(:filtering).with(:shrink_url, 'http://mikutter.d.hachune.net/').returns(['http://ha2.ne/39'])
    Plugin.stubs(:filtering).with(:is_expanded, 'http://google.jp/').returns(['http://google.jp/'])
    Plugin.stubs(:filtering).with(:is_expanded, 'http://mikutter.d.hachune.net/').returns(['http://mikutter.d.hachune.net/'])

    w = MessageConverters.shrink_url_all('watching: http://mikutter.d.hachune.net/')
    assert_equal('watching: http://ha2.ne/39', w)
    w = MessageConverters.shrink_url_all('watching: http://mikutter.d.hachune.net/ http://google.jp/')
    assert_equal("watching: http://ha2.ne/39 http://ha2.ne/156", w)
  end

  def test_expand
    Plugin.stubs(:filtering).with(:expand_url, 'http://ha2.ne/156').returns(['http://google.jp/'])
    Plugin.stubs(:filtering).with(:expand_url, 'http://ha2.ne/39').returns(['http://mikutter.d.hachune.net/'])
    Plugin.stubs(:filtering).with(:is_expanded, 'http://ha2.ne/39').returns([false])
    Plugin.stubs(:filtering).with(:is_expanded, 'http://ha2.ne/156').returns([false])
    Plugin.stubs(:filtering).with(:is_expanded, 'http://google.jp/').returns([true])
    Plugin.stubs(:filtering).with(:is_expanded, 'http://mikutter.d.hachune.net/').returns([true])

    w = MessageConverters.expand_url_all('watching: http://ha2.ne/156')
    assert_equal("watching: http://google.jp/", w)
    w = MessageConverters.expand_url_all('watching: http://ha2.ne/156 http://ha2.ne/39')
    assert_equal("watching: http://google.jp/ http://mikutter.d.hachune.net/", w)
  end
end
# >> Loaded suite -
# >> Started
# >> ..
# >> Finished in 0.003505 seconds.
# >> 
# >> 2 tests, 4 assertions, 0 failures, 0 errors
