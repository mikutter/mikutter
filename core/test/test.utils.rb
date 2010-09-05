# -*- coding: utf-8 -*-

require 'test/unit'
require File.dirname(__FILE__) + '/../utils'
require 'uri'

$debug = true
$debug_avail_level = 3

class TC_Utils < Test::Unit::TestCase

  def test_shrink
    text = '10.10の開発は9月2日のBetaリリースを控え，UserInterfaceFreeze・BetaFreezeを無事に通過しました。以降は原則としてGUI部分の大きな変更はなく，各機能のブラッシュアップに入ります。Ubuntu Weekly Topics　http://bit.ly/123456'
    assert_equal("10.10の開発は9月2日のBetaリリースを控え，UserInterfaceFreeze・BetaFreezeを無事に通過しました。以降は原則としてGUI部分の大きな変更はなく，各機能のブラッシュアップに入ります。Ubuntu Week http://bit.ly/123456", text.shrink(140, URI.regexp(['http','https'])))
  end

end
# >> Loaded suite -
# >> Started
# >> .
# >> Finished in 0.000773 seconds.
# >> 
# >> 1 tests, 1 assertions, 0 failures, 0 errors
