# -*- coding: utf-8 -*-

$LOAD_PATH.push(File.expand_path(File.join(File.dirname($0), '../..')))

require 'test/unit'
require 'mocha'
require 'webmock'
require 'mikutwitter/connect'
require 'test_unit_extensions'

class TC_mikutwitter_connect < Test::Unit::TestCase
  def setup
    @m = MikuTwitter.new
  end

  must "empty query string" do
    assert_equal("", @m.get_args({}))
  end

  must "single query" do
    assert_equal("?include_entities=true", @m.get_args(:include_entities => true))
  end

  must "excluded query" do
    assert_equal("?count=20", @m.get_args(:cache => true, :count => 20))
    assert_equal("", @m.get_args(:cache => true))
  end
end
