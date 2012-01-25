# -*- coding: utf-8 -*-

DIR = File.expand_path(File.dirname($0))
$LOAD_PATH.push(File.expand_path(File.join(File.dirname($0), '../../..')))

require 'test/unit'
require 'mocha'
require 'webmock/test_unit'
require 'pp'
require 'utils'
miquire :lib, 'test_unit_extensions', 'mikutwitter'

class TC_mikutwitter_api_call_support < Test::Unit::TestCase
  def setup
    MikuTwitter::ApiCallSupport::Request::Parser.stubs(:message_appear).returns(stub_everything)
    @m = MikuTwitter.new
  end

  must ".jsonで終わるURLに対するキャッシュファイルのパス" do
   assert_equal(File.expand_path(File.join(Environment::CACHE, "statuses/home_timeline.json")), @m.cache_file_path("statuses/home_timeline.json"))
  end

  must "クエリ文字列のついたURLに対するキャッシュファイルのパス" do
    assert_equal(File.expand_path(File.join(Environment::CACHE, "statuses/home_timeline.json.q/f/f469bbe168f13fd685fc22a70967570f")),
                 @m.cache_file_path("statuses/home_timeline.json?include_entities=1"))
  end

end
