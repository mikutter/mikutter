# -*- coding: utf-8 -*-

$LOAD_PATH.push(File.expand_path(File.join(File.dirname($0), '../..')))

require 'test/unit'
require 'mocha'
require 'webmock'
require 'mikutwitter/unauthorized'
require 'test_unit_extensions'

class Plugin
  def self.call(*args); end end

class TC_mikutwitter_unauthorized < Test::Unit::TestCase

  def setup
    @m = MikuTwitter.new
  end

  must "test request" do
    WebMock.stub_request(:get, 'http://api.twitter.com/1/help/test.json').to_return(:body => '"ok"', :status => 200)
    res = @m.query_without_oauth!(:get, 'http://api.twitter.com/1/help/test.json')
    assert_equal("200", res.code)
    assert_equal("\"ok\"", res.body)
  end
end
