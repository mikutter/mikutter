# -*- coding: utf-8 -*-

DIR = File.expand_path(File.dirname($0))
$LOAD_PATH.push(File.expand_path(File.join(File.dirname($0), '../../..')))

require 'test/unit'
require 'mocha'
require 'webmock/test_unit'
require 'pp'
require 'utils'
miquire :lib, 'test_unit_extensions', 'mikutwitter'
miquire :core, 'delayer'

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
    stub_request(:get, "http://api.twitter.com/1/statuses/show/154380989328662530.json?include_entities=true"). # !> assigned but unused variable - limit
      with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent'=>'Ruby'}).
      to_return(:status => 200, :body => file_get_contents(File.join(DIR, '154380989328662530.json')), :headers => {}) # !> previous definition of messages was here
    result = exception = nil
    (@m/:statuses/:show/154380989328662530).json(include_entities: true).next{ |json| # !> assigned but unused variable - remain
      result = json
    }
    wait_all_tasks
    assert_kind_of(Hash, result)
    assert_equal(154380989328662530, result[:id])
    assert_equal(15926668, result[:user][:id])
  end

end
