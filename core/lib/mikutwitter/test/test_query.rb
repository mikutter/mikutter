# -*- coding: utf-8 -*-

DIR = File.expand_path(File.dirname($0))
$LOAD_PATH.push(File.expand_path(File.join(File.dirname($0), '../../..')))

require 'test/unit'
require 'mocha'
require 'webmock'

require 'utils'
miquire :lib, 'mikutwitter/query', 'test_unit_extensions'

class Plugin
  def self.call(*args); end end

class TC_mikutwitter_query < Test::Unit::TestCase

  def setup
    @m = MikuTwitter.new
  end

  must "auto oauth query test" do
    @m.stubs(:necessary_oauth).returns({'help' => {'test' => true}}).once # help/testはOAuth必須とする
    WebMock.stub_request(:get, 'http://api.twitter.com/1/help/test.json').to_return(:body => '"ok"', :status => 200)
    res = @m.query!('help/test')
    assert_equal("200", res.code)
    assert_equal("\"ok\"", res.body)
  end

  must "auto ip query test" do
    @m.stubs(:necessary_oauth).returns({'help' => {'test' => false}}).once # help/testはOAuth不要とする
    WebMock.stub_request(:get, 'http://api.twitter.com/1/help/test.json').to_return(:body => '"ok"', :status => 200)
    res = @m.query!('help/test')
    assert_equal("200", res.code)
    assert_equal("\"ok\"", res.body)
  end

end
