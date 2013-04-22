# -*- coding: utf-8 -*-

require File.expand_path(File.dirname(__FILE__) + '/../helper')
#require File.expand_path(File.dirname(__FILE__) + '/../utils')
miquire :core, 'entity'
miquire :core, 'userconfig'

class Plugin
end

class String
  def inspect
    to_s
  end
end

module Pango
  ESCAPE_RULE = {'&' => '&amp;' ,'>' => '&gt;', '<' => '&lt;'}.freeze
  class << self

    # テキストをPango.parse_markupで安全にパースできるようにエスケープする。
    def escape(text)
      text.gsub(/[<>&]/){|m| Pango::ESCAPE_RULE[m] } end end end


class TC_Message < Test::Unit::TestCase

  THE_TWEET = '変な意味じゃなくてね。RT @kouichi_0308: アレでソレですか…(´･ω･｀)ｼｭﾝ… RT @nene_loveplus: 昔から一緒にいるフォロワーさんは色々アレでソレでちょっと困っちゃうわね…。'
  THE_ENTITY = {
    :user_mentions => [ { :id_str => "127914421",
                          :screen_name => "kouichi_0308",
                          :name => "コウイチ(2011年度版)",
                          :id => 127914421,
                          :indices => [14, 27]},
                        { :id_str => "95126742",
                          :screen_name => "nene_loveplus",
                          :name=>"姉ヶ崎寧々",
                          :id=>95126742,
                          :indices=>[53, 67]}],
    :urls => [],
    :hashtags => [] }

  THE_TWEET2 = '&#9829; Unfaithful by Rihanna #lastfm: http://bit.ly/3YP9Hq amazon: http://bit.ly/1tmPYb'
  THE_ENTITY2 = {
    :user_mentions=>[],
    :hashtags=> [ { :text=>"lastfm",
                    :indices=>[30, 37] } ],
    :urls=> [ { :expanded_url=>nil,
                :indices=>[39, 59],
                :url=>"http://bit.ly/3YP9Hq" },
              { :expanded_url=>nil,
                :indices=>[68, 88],
                :url=>"http://bit.ly/1tmPYb" } ] }

  THE_TWEET3 = 'RT @toshi_a: おいmikutterが変態ツイッタークライアントだという風説が'
  THE_ENTITY3 = {}

  def setup
    Plugin.stubs(:call).returns(true)
    Message::Entity.addlinkrule(:urls, URI.regexp(['http','https'])){ |segment| }
    Message::Entity.addlinkrule(:media){ |segment| }
    Message::Entity.addlinkrule(:hashtags, /(#|＃)([a-zA-Z0-9_]+)/){ |segment|}
    Message::Entity.addlinkrule(:user_mentions, /(@|＠|〄)[a-zA-Z0-9_]+/){ |segment| }
  end

  def teardown
    Message::Entity.refresh
  end

  def test_1
    mes = stub
    mes.stubs(:to_show).returns(THE_TWEET)
    mes.stubs(:[]).with(:entities).returns(THE_ENTITY)
    mes.stubs(:is_a?).with(Message).returns(true)

    entity = Message::Entity.new(mes)

    assert_equal("変な意味じゃなくてね。RT @kouichi_0308: アレでソレですか…(´･ω･｀)ｼｭﾝ… RT @nene_loveplus: 昔から一緒にいるフォロワーさんは色々アレでソレでちょっと困っちゃうわね…。", entity.to_s)

    splited = mes.to_show.split(//u).map{ |s| Pango::ESCAPE_RULE[s] || s }
    entity.reverse_each{ |l|
      splited[l[:range]] = '<span underline="single" underline_color="#000000">'+"#{Pango.escape(l[:face])}</span>"
    }
    splited
  end


  def test_2
    mes = stub
    mes.stubs(:to_show).returns(THE_TWEET2)
    mes.stubs(:[]).with(:entities).returns(THE_ENTITY2)
    mes.stubs(:is_a?).with(Message).returns(true)

    Plugin.stubs(:filtering).with(:expand_url, 'http://bit.ly/3YP9Hq').returns(['http://www.last.fm/music/Rihanna/_/Unfaithful'])
    Plugin.stubs(:filtering).with(:expand_url, 'http://bit.ly/1tmPYb').returns(['http://www.amazon.com/A-Girl-Like-Me/dp/B001144EBA?SubscriptionId=12CBBK5SPFDF9BJG9N82&tag=nickelscom-20&linkCode=xm2&camp=2025&creative=165953&creativeASIN=B001144EBA'])
    Plugin.stubs(:filtering).with(:is_expanded, 'http://bit.ly/3YP9Hq').returns([false])
    Plugin.stubs(:filtering).with(:is_expanded, 'http://bit.ly/1tmPYb').returns([false])
    Plugin.stubs(:filtering).with(:is_expanded, 'http://www.last.fm/music/Rihanna/_/Unfaithful').returns([true])
    Plugin.stubs(:filtering).with(:is_expanded, 'http://www.amazon.com/A-Girl-Like-Me/dp/B001144EBA?SubscriptionId=12CBBK5SPFDF9BJG9N82&tag=nickelscom-20&linkCode=xm2&camp=2025&creative=165953&creativeASIN=B001144EBA').returns([true])

    entity = Message::Entity.new(mes)

    # pp entity.to_a

    a = entity.to_a.map{ |x| x.dup.tap{|n|n.delete(:regexp)} }

    assert_kind_of(String, entity.to_s)
    assert_equal('&#9829; Unfaithful by Rihanna #lastfm: http://www.last.fm/music/Rihanna/_/Unfaithful amazon: http://www.amazon.com/A-Girl-Like-Me/dp/B001144EBA?SubscriptionId=12CBBK5SPFDF9BJG9N82&tag=nickelscom-20&linkCode=xm2&camp=2025&creative=165953&creativeASIN=B001144EBA', entity.to_s.inspect)
  end

  def test_3
    mes = stub
    mes.stubs(:to_show).returns(THE_TWEET3)
    mes.stubs(:[]).with(:entities).returns(THE_ENTITY3)
    mes.stubs(:is_a?).with(Message).returns(true)
    entity = Message::Entity.new(mes)
    assert_kind_of(String, entity.to_s)
    assert_equal("RT @toshi_a: \343\201\212\343\201\204mikutter\343\201\214\345\244\211\346\205\213\343\203\204\343\202\244\343\203\203\343\202\277\343\203\274\343\202\257\343\203\251\343\202\244\343\202\242\343\203\263\343\203\210\343\201\240\343\201\250\343\201\204\343\201\206\351\242\250\350\252\254\343\201\214", entity.to_s.inspect)
  end

  def test_4
    tweet = 'もともとは@penguin2716さんに勧められて始めたついった。そして彼より遅く始めた自分がTwitterにハマり、彼の総ポスト数をすぐに追い抜いたと思ったのですが、今や彼はれっきとしたmikutter廃人となり、ワタシの手の届かぬ領域に到達されました。'
    mes = stub
    mes.stubs(:to_show).returns(tweet)
    mes.stubs(:[]).with(:entities).returns({})
    mes.stubs(:is_a?).with(Message).returns(true)
    entity = Message::Entity.new(mes)

    assert_kind_of(String, entity.to_s)
    assert_equal(tweet, entity.to_s.inspect)
  end

  def test_5
    tweet = '一体何をやってんだろう(笑)。 > @toshi_a the hacker'
    mes = stub
    mes.stubs(:to_show).returns(tweet)
    mes.stubs(:[]).with(:entities).returns({:hashtags=>[], :urls=>[], :user_mentions=>[{:name=>"蝶舞スカーフ型としぁ", :screen_name=>"toshi_a", :indices=>[21, 29], :id=>15926668, :id_str=>"15926668"}]})
    mes.stubs(:is_a?).with(Message).returns(true)
    entity = Message::Entity.new(mes)

    assert_kind_of(String, entity.to_s)
    assert_equal(tweet, entity.to_s.inspect)
  end

  def test_6
    Plugin.stubs(:filtering).with(:is_expanded, 'goo.gl/2tsIG').returns([true])
    tweet = 'まだまだ絶賛配信中！今日は「日常のラヂオ」第３５回がランティスネットラジオ goo.gl/2tsIG にて２２時から配信スタートです！「日常」が好きな人ならきっと楽しんでいただけますのでよろしくお願いします。 #nichijou'
    mes = stub
    mes.stubs(:to_show).returns(tweet)
    mes.stubs(:[]).with(:entities).
      returns({ :user_mentions=>[],
                :urls     => [{ :url=>"goo.gl/2tsIG",
                                :indices=>[38, 50],
                                :expanded_url=>nil } ],
                :hashtags => [{ :indices=>[105, 114],
                                :text=>"nichijou" } ]})
    mes.stubs(:is_a?).with(Message).returns(true)
    entity = Message::Entity.new(mes)

    assert_kind_of(String, entity.to_s)
    assert_equal(tweet, entity.to_s.inspect)
  end

  def test_7
    tweet = "@uebayasi I tried and it works as below:\n$ uname -srm\nNetBSD 6.0.1 amd64\n$  s ( ) { local b; b=1; echo $b; b=\"$@\"; echo $b; }\n$ s d e\n1\nd e"
    mes = stub
    mes.stubs(:to_show).returns(tweet)
    mes.stubs(:[]).with(:id).returns(325862212793159680)
    mes.stubs(:[]).with(:message).returns(tweet)
    mes.stubs(:[]).with(:entities).
      returns({ hashtags: [], 
                symbols: [{ indices: [103, 105], 
                            text: "b"},
                          { indices: [120, 122],
                            text: "b"}],
                urls: [], 
                user_mentions: [{ id: 5864792, 
                                  id_str: "5864792", 
                                  indices: [0, 9],
                                  name: "Masao Uebayashi", 
                                  screen_name: "uebayasi" }]})
    mes.stubs(:is_a?).with(Message).returns(true)
    entity = Message::Entity.new(mes)

    assert_kind_of(String, entity.to_s)
    assert_equal(tweet, entity.to_s.inspect)
  end

end

