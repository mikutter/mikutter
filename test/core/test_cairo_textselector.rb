# -*- coding: utf-8 -*-
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
  S4 = 'エンティティのテスト &lt;&lt;&lt;&lt; &amp;&amp;&amp;&amp; &gt;&gt;&gt; ておくれ'
  S5 = 'f<a><b>a</b>v</a>'
  S6 = <<EOM
　　し
　じ　　    ／￣￣￣＼
ん　　　  /　　ー 、　　   \
｜　　　  \　　　   )　　  ｜
  \　　　　ヽーー~　　　 /
　＼　　　　　　　　　／
　　＼　　　　　　　／
　　　ヽーーーーー~
EOM

  def setup
  end

  def test_new_line
    mp = MockPainter.new

    s6 = S6.scan(Gdk::TextSelector::CHUNK_PATTERN)
    assert_equal 'し', s6[mp.get_aindex(s6, 2)]
    assert_equal "\n", s6[mp.get_aindex(s6, 3)]
  end

  def test_get_aindex
    mp = MockPainter.new

    s1 = S1.scan(Gdk::TextSelector::CHUNK_PATTERN)
    assert_equal 8, mp.get_aindex(s1, 8)
    assert_equal 10, mp.get_aindex(s1, 9)
    assert_equal 9, mp.get_aindex(s1, 8, last: true)
    assert_equal 10, mp.get_aindex(s1, 9, last: true)

    s5 = S5.scan(Gdk::TextSelector::CHUNK_PATTERN)
    assert_equal 0, mp.get_aindex(s5, 0)
    assert_equal 1, mp.get_aindex(s5, 1)
    assert_equal 4, mp.get_aindex(s5, 2)
    assert_equal 3, mp.get_aindex(s5, 1, last: true)
    assert_equal 5, mp.get_aindex(s5, 2, last: true)

    assert_equal 9, mp.get_aindex(S2.scan(Gdk::TextSelector::CHUNK_PATTERN), 9)
  end

  def test_select
    mp = MockPainter.new
    assert_equal('th<span background="#000000" foreground="#ffffff">is is </span><b><span background="#000000" foreground="#ffffff">a </span><a><span background="#000000" foreground="#ffffff">te</span>st</a></b> text',
                 mp.textselector_press(2).textselector_release(12).textselector_markup(S1))
    assert_equal('th<span background="#000000" foreground="#ffffff">is i</span>s <b>a <a>test</a></b> text',
                 mp.textselector_press(2).textselector_release(6).textselector_markup(S1))
    assert_equal('th<span background="#000000" foreground="#ffffff">is is <b>a <a>test</a></b> tex</span>t',
                 mp.textselector_press(2).textselector_release(18).textselector_markup(S1))

    assert_equal('esca<span background="#000000" foreground="#ffffff">pe &gt; </span>text',
                 mp.textselector_press(4).textselector_release(9).textselector_markup(S2))

    assert_equal('にほ<span background="#000000" foreground="#ffffff">んごも</span>じれつ',
                 mp.textselector_press(2).textselector_release(5).textselector_markup(S3))

    assert_equal('エンティティのテス<span background="#000000" foreground="#ffffff">ト</span> &lt;&lt;&lt;&lt; &amp;&amp;&amp;&amp; &gt;&gt;&gt; ておくれ',
                 mp.textselector_press(9).textselector_release(10).textselector_markup(S4))

    assert_equal('エンティティのテス<span background="#000000" foreground="#ffffff">ト </span>&lt;&lt;&lt;&lt; &amp;&amp;&amp;&amp; &gt;&gt;&gt; ておくれ',
                 mp.textselector_press(9).textselector_release(11).textselector_markup(S4))

    assert_equal('エンティティのテス<span background="#000000" foreground="#ffffff">ト &lt;</span>&lt;&lt;&lt; &amp;&amp;&amp;&amp; &gt;&gt;&gt; ておくれ',
                 mp.textselector_press(9).textselector_release(12).textselector_markup(S4))

  end

end
# >> Loaded suite -
# >> Started
# >> .
# >> Finished in 0.002221 seconds.
# >> 
# >> 1 tests, 5 assertions, 0 failures, 0 errors
