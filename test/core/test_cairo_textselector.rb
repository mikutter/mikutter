# -*- coding: utf-8 -*-
require 'test/unit'
$cairo = true
require File.expand_path(File.dirname(__FILE__) + '/../helper')
# require File.expand_path(File.dirname(__FILE__) + '/../utils')
miquire :mui, 'textselector'

$debug = true # !> instance variable @textselect_start not initialized
# seterrorlevel(:notice)
$logfile = nil
$daemon = false

class MockPainter
  include Gdk::TextSelector
  def on_modify
  end
end

class TC_TextSelector < Test::Unit::TestCase

  S1 = 'this is <b>a <a>test</a></b> text'.freeze
  S2 = 'escape &gt; text'
  S3 = 'にほんごもじれつ'

  def setup
  end

  def test_select
    mp = MockPainter.new
    assert_equal('th<span background="#000000" foreground="#ffffff">is is </span><b><span background="#000000" foreground="#ffffff">a </span><a><span background="#000000" foreground="#ffffff">te</span>st</a></b> text',
                 mp.textselector_press(2).textselector_release(12).textselector_markup(S1))
    assert_equal('th<span background="#000000" foreground="#ffffff">is i</span>s <b>a <a>test</a></b> text',
                 mp.textselector_press(2).textselector_release(6).textselector_markup(S1))
    assert_equal('th<span background="#000000" foreground="#ffffff">is is <b>a <a>test</a></b> tex</span>t',
                 mp.textselector_press(2).textselector_release(18).textselector_markup(S1))

    assert_equal('esca<span background="#000000" foreground="#ffffff">pe &gt; t</span>ext',
                 mp.textselector_press(4).textselector_release(9).textselector_markup(S2))

    assert_equal('にほ<span background="#000000" foreground="#ffffff">んごも</span>じれつ',
                 mp.textselector_press(2).textselector_release(5).textselector_markup(S3))

  end

end
# >> Loaded suite -
# >> Started
# >> .
# >> Finished in 0.002221 seconds.
# >> 
# >> 1 tests, 5 assertions, 0 failures, 0 errors
