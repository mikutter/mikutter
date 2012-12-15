# -*- coding: utf-8 -*-
require "#{File.dirname(__FILE__)}/extension"

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
    WebMock.stub_request(:get, "#{@m.base_path}/application/rate_limit_status.json").to_return(:body => '"ok"', :status => 200)
    res = @m.query!('application/rate_limit_status')
    assert_equal("200", res.code)
    assert_equal("\"ok\"", res.body)
  end

end
