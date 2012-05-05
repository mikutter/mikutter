# -*- coding: utf-8 -*-

DIR = File.expand_path(File.dirname($0))
$LOAD_PATH.push(File.expand_path(File.join(File.dirname($0), '../../..')))

require 'test/unit'
require 'mocha'
require 'webmock'

require 'utils'
miquire :lib, 'mikutwitter/streaming_failed_actions', 'test_unit_extensions'

class Plugin # !> assigned but unused variable - e
  def self.call(*args); end end

class TC_mikutwitter_query < Test::Unit::TestCase

  def setup
    @m = MikuTwitter.new
  end

  must "success" do
    f = MikuTwitter::StreamingFailedActions.new('tester', mock())
    f.success
  end

  must "unauthorized then success" do
    plugin = mock()
    res = mock()
    res.expects(:code).returns('401').at_least(0)
    res.expects(:body).returns('Unauthorized').at_least(0)

    f = MikuTwitter::StreamingFailedActions.new('tester', plugin)

    f.stubs(:client_bug).with(res).returns(nil).once

    f.notify(res)

    assert_equal("401", f.last_code)

    plugin.stubs(:activity).with(:error, "tester: 接続できました。",
                                 description: "tester: 接続できました。\n").returns(nil).once

    f.success
  end

  must "rate limit then success" do
    plugin = mock()
    res = mock()
    res.expects(:code).returns('420').at_least(0)
    res.expects(:body).returns('Rate Limit').at_least(0)

    f = MikuTwitter::StreamingFailedActions.new('tester', plugin)

    f.stubs(:rate_limit).with(res).returns(nil).once

    f.notify(res)

    assert_equal("420", f.last_code)

    plugin.stubs(:activity).with(:error, "tester: 接続できました。",
                                 description: "tester: 接続できました。\n規制解除されたみたいですね。よかったですね。").returns(nil).once

    f.success
  end


  must "server error then success" do
    plugin = mock()
    res = mock()
    res.expects(:code).returns('503').at_least(0)
    res.expects(:body).returns('Internal Server Error').at_least(0)

    f = MikuTwitter::StreamingFailedActions.new('tester', plugin)

    f.stubs(:flying_whale).with(res).returns(nil).once

    f.notify(res)

    assert_equal("503", f.last_code)

    plugin.stubs(:activity).with(:error, "tester: 接続できました。",
                                 description: "tester: 接続できました。\nまだTwitterサーバが完全には復旧していないかも知れません。\n"+
                                 "Twitterサーバの情報は以下のWebページで確認することができます。\nhttps://dev.twitter.com/status").returns(nil).once

    f.success
  end

  must "Runtime error then success" do
    plugin = mock()

    f = MikuTwitter::StreamingFailedActions.new('tester', plugin)

    f.notify(RuntimeError.new())

    plugin.stubs(:activity).never

    f.success
  end

end
