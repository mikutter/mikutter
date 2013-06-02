# -*- coding: utf-8 -*-
require "#{File.dirname(__FILE__)}/extension"
require 'test/unit'
require 'mocha'
require 'webmock/test_unit'
require 'pp'
require 'utils'

miquire :lib, 'delayer', 'test_unit_extensions', 'mikutwitter'

class Plugin
  def self.call(*args); end end

class TC_mikutwitter_api_call_support < Test::Unit::TestCase

  def setup
    wait_all_tasks
    @m = MikuTwitter.new
  end

  def wait_all_tasks
    while !Delayer.empty? or !(Thread.list - [Thread.current]).empty?
      Delayer.run
      (Thread.list - [Thread.current]).each &:join
    end
    assert_equal true, Delayer.empty?
    assert_equal [], (Thread.list - [Thread.current])
  end

  must "get home timeline" do
    stub_request(:get, "http://api.twitter.com/1.1/statuses/show.json?id=154380989328662530").
      to_return(:status => 200, :body => file_get_contents(File.join(MIKUTWITTER_TEST_DIR, '154380989328662530.json')), :headers => {}) # !> previous definition of messages was herey
    result = exception = nil
    (@m/:statuses/:show).json(id: 154380989328662530).next{ |json| # !> assigned but unused variable - remain
      result = json
    }
    wait_all_tasks
    assert_kind_of(Hash, result)
    assert_equal(154380989328662530, result[:id])
    assert_equal(15926668, result[:user][:id])
  end

end
