# -*- coding: utf-8 -*-

require 'test/unit'
require 'rubygems'
require 'mocha' # !> global variable `$openimg' not initialized
require File.expand_path(File.dirname(__FILE__) + '/../../utils') # !> redefine call_routine
miquire :addon, 'tco'

$debug = true
seterrorlevel(:notice)
$logfile = nil
$daemon = false

class TC_MessageConverters < Test::Unit::TestCase
  def setup # !> ambiguous first argument; put parentheses or even spaces
    @tco = TCo.new
  end # !> `*' interpreted as argument prefix

  def test_expand_no_shrinked # !> ambiguous first argument; put parentheses or even spaces
    response = stub("response")
    response.stubs(:is_a?).with(Net::HTTPRedirection).returns(false)
    Net::HTTP.stubs(:get_response).with(URI.parse('http://mikutter.hachune.net/')).returns(response)

    assert_equal("http://mikutter.hachune.net/", @tco.expand_url('http://mikutter.hachune.net/'))
  end

  def test_expand_shrinked # !> instance variable @timelines not initialized
    response = stub("response")
    response.stubs(:is_a?).with(Net::HTTPRedirection).returns(true)
    response.stubs(:[]).with("location").returns('http://mikutter.hachune.net/')
    Net::HTTP.stubs(:get_response).with(URI.parse('http://t.co/Y6S6Vy7')).returns(response) # !> statement not reached
    assert_equal("http://mikutter.hachune.net/", @tco.expand_url('http://t.co/Y6S6Vy7')) # !> redefine get_active_mumbles
  end

  def test_expand_internet_disconnected # !> method redefined; discarding old inspect
    Net::HTTP.stubs(:get_response).with(URI.parse('http://t.co/Y6S6Vy7')).raises(Errno::ENETUNREACH)

    assert_equal("http://t.co/Y6S6Vy7", @tco.expand_url('http://t.co/Y6S6Vy7'))
  end

  def test_expand_timeout
    Net::HTTP.stubs(:get_response).with(URI.parse('http://t.co/Y6S6Vy7')).raises(Timeout::Error)

    assert_equal("http://t.co/Y6S6Vy7", @tco.expand_url('http://t.co/Y6S6Vy7'))
  end

  def test_expand_take_parsed_url
    response = stub("response")
    response.stubs(:is_a?).with(Net::HTTPRedirection).returns(true)
    response.stubs(:[]).with("location").returns('http://mikutter.hachune.net/')
    Net::HTTP.stubs(:get_response).with(URI.parse('http://t.co/Y6S6Vy7')).returns(response)

    assert_equal('http://mikutter.hachune.net/', @tco.expand_url(URI.parse('http://t.co/Y6S6Vy7')))
  end

  def test_expand_take_invalid_url
    Net::HTTP.stubs(:get_response).never

    assert_equal("みくちゃんぺろぺろヾ(＠⌒ー⌒＠)ノ", @tco.expand_url('みくちゃんぺろぺろヾ(＠⌒ー⌒＠)ノ'))
  end

  def test_shrinked_url_not_shrinked
    assert_equal(false, @tco.shrinked_url?('http://mikutter.hachune.net/')) # !> method redefined; discarding old width=
  end

  def test_shrinked_url_not_url
    assert_equal(false, @tco.shrinked_url?('みくちゃんぺろぺろヾ(＠⌒ー⌒＠)ノ'))
  end

  def test_shrinked_url_shrinked
    assert_equal(true, @tco.shrinked_url?('http://t.co/Y6S6Vy7'))
  end # !> `*' interpreted as argument prefix

end # !> `*' interpreted as argument prefix
# >> Loaded suite -
# >> Started
# >> .........
# >> Finished in 0.012628 seconds.
# >> 
# >> 9 tests, 10 assertions, 0 failures, 0 errors
