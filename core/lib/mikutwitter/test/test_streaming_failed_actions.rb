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

    plugin.stubs(:activity).with(:status, "tester: 接続できました。",
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

    plugin.stubs(:activity).with(:status, "tester: 接続できました。",
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

    plugin.stubs(:activity).with(:status, "tester: 接続できました。",
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

  must "http error fail count" do
    plugin = mock()
    res = mock()
    res.expects(:code).returns('503').at_least(0)
    res.expects(:body).returns('Internal Server Error').at_least(0) # !> ambiguous first argument; put parentheses or even spaces

    f = MikuTwitter::StreamingFailedActions.new('tester', plugin)

    f.stubs(:flying_whale).with(res).returns(nil).once

    f.notify(res) # !> `&' interpreted as argument prefix

    assert_equal(0, f.wait_time)
    assert_equal(1, f.fail_count)

    f.notify(res)

    assert_equal(10, f.wait_time)
    assert_equal(2, f.fail_count)

    f.notify(res)

    assert_equal(20, f.wait_time)
    assert_equal(3, f.fail_count)

    f.notify(res)

    assert_equal(40, f.wait_time)
    assert_equal(4, f.fail_count)

    f.notify(res)

    assert_equal(80, f.wait_time)
    assert_equal(5, f.fail_count)

    f.notify(res)

    assert_equal(160, f.wait_time)
    assert_equal(6, f.fail_count)

    f.notify(res)

    assert_equal(240, f.wait_time)
    assert_equal(7, f.fail_count)

    f.notify(res)

    assert_equal(240, f.wait_time)
    assert_equal(8, f.fail_count)
  end

  must "tcp error fail count" do
    plugin = mock()
    res = RuntimeError.new

    f = MikuTwitter::StreamingFailedActions.new('tester', plugin)

    f.notify(res)

    assert_equal(0, f.wait_time)
    assert_equal(1, f.fail_count)

    f.notify(res)

    assert_in_delta(0.25, f.wait_time, 0.0001)
    assert_equal(2, f.fail_count)

    f.notify(res)

    assert_in_delta(0.5, f.wait_time, 0.0001)
    assert_equal(3, f.fail_count)

    f.notify(res)

    assert_in_delta(0.75, f.wait_time, 0.0001)
    assert_equal(4, f.fail_count)

    f.notify(res)

    assert_in_delta(1.0, f.wait_time, 0.0001)
    assert_equal(5, f.fail_count)

    f.notify(res)

    assert_in_delta(1.25, f.wait_time, 0.0001)
    assert_equal(6, f.fail_count)

    f.notify(res)

    assert_in_delta(1.5, f.wait_time, 0.0001)
    assert_equal(7, f.fail_count)

    f.notify(res)

    assert_in_delta(1.75, f.wait_time, 0.0001)
    assert_equal(8, f.fail_count)

    f.notify(res)

    assert_in_delta(2.0, f.wait_time, 0.0001)
    assert_equal(9, f.fail_count)
 # !> `&' interpreted as argument prefix
    f.notify(res)

    assert_in_delta(2.25, f.wait_time, 0.0001)
    assert_equal(10, f.fail_count)

    f.notify(res)

    assert_in_delta(2.5, f.wait_time, 0.0001)
    assert_equal(11, f.fail_count)

    f.notify(res)

    assert_in_delta(2.75, f.wait_time, 0.0001)
    assert_equal(12, f.fail_count)
 # !> mismatched indentations at 'end' with 'class' at 192
    f.notify(res)

    assert_in_delta(3.0, f.wait_time, 0.0001)
    assert_equal(13, f.fail_count)

    f.notify(res)

    assert_in_delta(3.25, f.wait_time, 0.0001)
    assert_equal(14, f.fail_count)

    f.notify(res)

    assert_in_delta(3.5, f.wait_time, 0.0001)
    assert_equal(15, f.fail_count)

    f.notify(res)

    assert_in_delta(3.75, f.wait_time, 0.0001)
    assert_equal(16, f.fail_count)

    f.notify(res)

    assert_in_delta(4.0, f.wait_time, 0.0001)
    assert_equal(17, f.fail_count)

    f.notify(res)

    assert_in_delta(4.25, f.wait_time, 0.0001)
    assert_equal(18, f.fail_count)

    f.notify(res)

    assert_in_delta(4.5, f.wait_time, 0.0001)
    assert_equal(19, f.fail_count)

    f.notify(res)

    assert_in_delta(4.75, f.wait_time, 0.0001)
    assert_equal(20, f.fail_count)

    f.notify(res)

    assert_in_delta(5.0, f.wait_time, 0.0001)
    assert_equal(21, f.fail_count)

    f.notify(res)

    assert_in_delta(5.25, f.wait_time, 0.0001)
    assert_equal(22, f.fail_count)

    f.notify(res)

    assert_in_delta(5.5, f.wait_time, 0.0001)
    assert_equal(23, f.fail_count)

    f.notify(res)

    assert_in_delta(5.75, f.wait_time, 0.0001)
    assert_equal(24, f.fail_count)

    f.notify(res)

    assert_in_delta(6.0, f.wait_time, 0.0001)
    assert_equal(25, f.fail_count)

    f.notify(res)

    assert_in_delta(6.25, f.wait_time, 0.0001)
    assert_equal(26, f.fail_count)

    f.notify(res)

    assert_in_delta(6.5, f.wait_time, 0.0001)
    assert_equal(27, f.fail_count)

    f.notify(res)

    assert_in_delta(6.75, f.wait_time, 0.0001)
    assert_equal(28, f.fail_count)

    f.notify(res)

    assert_in_delta(7.0, f.wait_time, 0.0001)
    assert_equal(29, f.fail_count)

    f.notify(res)

    assert_in_delta(7.25, f.wait_time, 0.0001)
    assert_equal(30, f.fail_count)

    f.notify(res)

    assert_in_delta(7.5, f.wait_time, 0.0001)
    assert_equal(31, f.fail_count)

    f.notify(res)

    assert_in_delta(7.75, f.wait_time, 0.0001)
    assert_equal(32, f.fail_count)

    f.notify(res)

    assert_in_delta(8.0, f.wait_time, 0.0001)
    assert_equal(33, f.fail_count)

    f.notify(res)

    assert_in_delta(8.25, f.wait_time, 0.0001)
    assert_equal(34, f.fail_count)

    f.notify(res)

    assert_in_delta(8.5, f.wait_time, 0.0001)
    assert_equal(35, f.fail_count)

    f.notify(res)

    assert_in_delta(8.75, f.wait_time, 0.0001)
    assert_equal(36, f.fail_count)

    f.notify(res)

    assert_in_delta(9.0, f.wait_time, 0.0001)
    assert_equal(37, f.fail_count)

    f.notify(res)

    assert_in_delta(9.25, f.wait_time, 0.0001)
    assert_equal(38, f.fail_count)

    f.notify(res)

    assert_in_delta(9.5, f.wait_time, 0.0001)
    assert_equal(39, f.fail_count)

    f.notify(res)

    assert_in_delta(9.75, f.wait_time, 0.0001)
    assert_equal(40, f.fail_count)

    f.notify(res)

    assert_in_delta(10.0, f.wait_time, 0.0001)
    assert_equal(41, f.fail_count)

    f.notify(res)

    assert_in_delta(10.25, f.wait_time, 0.0001)
    assert_equal(42, f.fail_count)

    f.notify(res)

    assert_in_delta(10.5, f.wait_time, 0.0001)
    assert_equal(43, f.fail_count)

    f.notify(res)

    assert_in_delta(10.75, f.wait_time, 0.0001)
    assert_equal(44, f.fail_count)

    f.notify(res)

    assert_in_delta(11.0, f.wait_time, 0.0001)
    assert_equal(45, f.fail_count)

    f.notify(res)

    assert_in_delta(11.25, f.wait_time, 0.0001)
    assert_equal(46, f.fail_count)

    f.notify(res)

    assert_in_delta(11.5, f.wait_time, 0.0001)
    assert_equal(47, f.fail_count)

    f.notify(res)

    assert_in_delta(11.75, f.wait_time, 0.0001)
    assert_equal(48, f.fail_count)

    f.notify(res)

    assert_in_delta(12.0, f.wait_time, 0.0001)
    assert_equal(49, f.fail_count)

    f.notify(res)

    assert_in_delta(12.25, f.wait_time, 0.0001)
    assert_equal(50, f.fail_count)

    f.notify(res)

    assert_in_delta(12.5, f.wait_time, 0.0001)
    assert_equal(51, f.fail_count)

    f.notify(res)

    assert_in_delta(12.75, f.wait_time, 0.0001)
    assert_equal(52, f.fail_count)

    f.notify(res)

    assert_in_delta(13.0, f.wait_time, 0.0001)
    assert_equal(53, f.fail_count)

    f.notify(res)

    assert_in_delta(13.25, f.wait_time, 0.0001)
    assert_equal(54, f.fail_count)

    f.notify(res)

    assert_in_delta(13.5, f.wait_time, 0.0001)
    assert_equal(55, f.fail_count)

    f.notify(res)

    assert_in_delta(13.75, f.wait_time, 0.0001)
    assert_equal(56, f.fail_count)

    f.notify(res)

    assert_in_delta(14.0, f.wait_time, 0.0001)
    assert_equal(57, f.fail_count)

    f.notify(res)

    assert_in_delta(14.25, f.wait_time, 0.0001)
    assert_equal(58, f.fail_count)

    f.notify(res)

    assert_in_delta(14.5, f.wait_time, 0.0001)
    assert_equal(59, f.fail_count)

    f.notify(res)

    assert_in_delta(14.75, f.wait_time, 0.0001)
    assert_equal(60, f.fail_count)

    f.notify(res)

    assert_in_delta(15.0, f.wait_time, 0.0001)
    assert_equal(61, f.fail_count)

    f.notify(res)

    assert_in_delta(15.25, f.wait_time, 0.0001)
    assert_equal(62, f.fail_count)

    f.notify(res)

    assert_in_delta(15.5, f.wait_time, 0.0001)
    assert_equal(63, f.fail_count)

    f.notify(res)

    assert_in_delta(15.75, f.wait_time, 0.0001)
    assert_equal(64, f.fail_count)

    f.notify(res)

    assert_in_delta(16.0, f.wait_time, 0.0001)
    assert_equal(65, f.fail_count)

    f.notify(res)

    assert_equal(16, f.wait_time)
    assert_equal(66, f.fail_count)

  end


end
# >> Run options: 
# >> 
# >> # Running tests:
# >> 
# >> .......
# >> 
# >> Finished tests in 0.003822s, 1831.7357 tests/s, 41606.5683 assertions/s.
# >> 
# >> 7 tests, 159 assertions, 0 failures, 0 errors, 0 skips
