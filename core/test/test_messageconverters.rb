# -*- coding: utf-8 -*-
require 'test/unit'
require File.expand_path(File.dirname(__FILE__) + '/../utils')
miquire :addon, 'bitly'

$debug = true
seterrorlevel(:notice)
$logfile = nil
$daemon = false

class TC_MessageConverters < Test::Unit::TestCase
  def setup
  end

  def test_shrink # !> ambiguous first argument; put parentheses or even spaces
    w = MessageConverters.shrink_url_all('watching: http://mikutter.d.hachune.net/')
    assert_equal("watching: http://bit.ly/dmIqSo", w) # !> `*' interpreted as argument prefix
  end
 # !> ambiguous first argument; put parentheses or even spaces
  def test_expand
    w = MessageConverters.expand_url_all('watching: http://mikutter.d.hachune.net/')
    assert_equal("watching: http://mikutter.d.hachune.net/", w)
    w = MessageConverters.expand_url_all('watching: http://bit.ly/dmIqSo')
    assert_equal("watching: http://mikutter.d.hachune.net/", w)
  end
end
# >> Loaded suite -
# >> Started
# >> ..
# >> Finished in 0.613949 seconds.
# >> 
# >> 2 tests, 3 assertions, 0 failures, 0 errors
