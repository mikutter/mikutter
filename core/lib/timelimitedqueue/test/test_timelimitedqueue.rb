# -*- coding: utf-8 -*-

require 'test/unit'
require File.expand_path(File.join('..', 'timelimitedqueue'))

class TC_TimeLimitedQueue < Test::Unit::TestCase
  def setup
    Thread.abort_on_exception = true
  end

  # def teardown
  # end

  def test_output
    tlq = TimeLimitedQueue.new(10, 1){ |v| p v }
    100.times{ |n|
      tlq.push(n) }
    assert_equal(tlq.thread.group, TimeLimitedQueue::TLQGroup)
    # sleep(1)
  end

end
# >> Loaded suite -
# >> Started
# >> .
# >> Finished in 0.001979 seconds.
# >> 
# >> 1 tests, 1 assertions, 0 failures, 0 errors
