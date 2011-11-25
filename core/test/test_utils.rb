# -*- coding: utf-8 -*-

require 'test/unit'
require 'uri'
require File.expand_path(File.dirname(__FILE__) + '/../utils')
miquire :lib, 'test_unit_extensions'

$debug = true
$debug_avail_level = 3

class TC_Utils < Test::Unit::TestCase

  must "shrink too long text includs url in tail" do
    text = '10.10の開発は9月2日のBetaリリースを控え，UserInterfaceFreeze・BetaFreezeを無事に通過しました。以降は原則としてGUI部分の大きな変更はなく，各機能のブラッシュアップに入ります。Ubuntu Weekly Topics　http://bit.ly/123456'
    assert_equal("10.10の開発は9月2日のBetaリリースを控え，UserInterfaceFreeze・BetaFreezeを無事に通過しました。以降は原則としてGUI部分の大きな変更はなく，各機能のブラッシュアップに入ります。Ubuntu Week http://bit.ly/123456", text.shrink(140, URI.regexp(['http','https'])))
  end

  must "shrink too long url only" do
    text = 'http://aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.com' # aが140回
    assert_equal(text, text.shrink(140, URI.regexp(['http','https'])))
  end

end
