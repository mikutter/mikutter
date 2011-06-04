# -*- coding: utf-8 -*-

require 'test/unit'
require 'rubygems'
require 'mocha'
require File.expand_path(File.dirname(__FILE__) + '/../../utils')
miquire :addon, 'bitly'

$debug = true
seterrorlevel(:notice)
$logfile = nil
$daemon = false

class TC_MessageConverters < Test::Unit::TestCase
  def setup # !> ambiguous first argument; put parentheses or even spaces
  end
 # !> `*' interpreted as argument prefix
  def test_shrink
    UserConfig.stubs(:[]).with(:bitly_user).returns(nil) # !> ambiguous first argument; put parentheses or even spaces
    UserConfig.stubs(:[]).with(:bitly_apikey).returns(nil)
    UserConfig.stubs(:[]).with(:proxy_enabled).returns(nil)

    w = MessageConverters.shrink_url_all('watching: http://mikutter.hachune.net/')
    assert_equal("watching: http://bit.ly/90tFUh", w)
    w = MessageConverters.shrink_url_all('watching: http://google.jp/ http://google.com/')
    assert_equal("watching: http://bit.ly/bkUjey http://bit.ly/gsU1Ic", w)
  end

  def test_expand
    UserConfig.stubs(:[]).with(:bitly_user).returns(nil)
    UserConfig.stubs(:[]).with(:bitly_apikey).returns(nil) # !> statement not reached
    UserConfig.stubs(:[]).with(:proxy_enabled).returns(nil)

    w = MessageConverters.expand_url_all('watching: http://mikutter.d.hachune.net/')
    assert_equal("watching: http://mikutter.d.hachune.net/", w) # !> redefine get_active_mumbles
    w = MessageConverters.expand_url_all('watching: http://bit.ly/90tFUh')
    assert_equal("watching: http://mikutter.hachune.net/", w)
    w = MessageConverters.expand_url_all("watching: http://bit.ly/bkUjey http://bit.ly/gsU1Ic")
    assert_equal('watching: http://google.jp/ http://google.com/', w)
  end
end
# ~> notice: ./addon/bitly/bitly.rb:80:in `expand_url_many': http://bit.ly/90tFUh
# ~> notice: ./addon/bitly/bitly.rb:80:in `expand_url_many': http://bit.ly/bkUjey
# ~> notice: ./addon/bitly/bitly.rb:80:in `expand_url_many': http://bit.ly/gsU1Ic
# >> Loaded suite -
# >> Started
# >> ..
# >> Finished in 2.222549 seconds.
# >> 
# >> 2 tests, 5 assertions, 0 failures, 0 errors
