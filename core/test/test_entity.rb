# -*- coding: utf-8 -*-

require 'test/unit'
require 'rubygems'
require 'mocha'
require 'pp'
require File.expand_path(File.dirname(__FILE__) + '/../utils')
miquire :core, 'entity'
miquire :core, 'userconfig'

$debug = true
seterrorlevel(:notice)
$logfile = nil
$daemon = false
 # !> ambiguous first argument; put parentheses or even spaces
Message::Entity.addlinkrule(:urls, URI.regexp(['http','https'])){ |segment| }
Message::Entity.addlinkrule(:media){ |segment| } # !> discarding old diag
Message::Entity.addlinkrule(:hashtags, /[#＃]([a-zA-Z0-9_]+)/){ |segment|}
Message::Entity.addlinkrule(:user_mentions, /[@＠〄][a-zA-Z0-9_]+/){ |segment| } # !> ambiguous first argument; put parentheses or even spaces


class Plugin
end

class String
  def inspect # !> method redefined; discarding old inspect
    to_s
  end
end

module Pango
  ESCAPE_RULE = {'&' => '&amp;' ,'>' => '&gt;', '<' => '&lt;'}.freeze
  class << self

    # テキストをPango.parse_markupで安全にパースできるようにエスケープする。 # !> method redefined; discarding old inspect
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
    :hashtags=> [ { :text=>"lastfm", # !> instance variable @busy not initialized
                    :indices=>[30, 37] } ],
    :urls=> [ { :expanded_url=>nil,
                :indices=>[39, 59],
                :url=>"http://bit.ly/3YP9Hq" },
              { :expanded_url=>nil,
                :indices=>[68, 88],
                :url=>"http://bit.ly/1tmPYb" } ] }

  def setup
  end
 # !> `*' interpreted as argument prefix
  def test_1
    mes = stub # !> `*' interpreted as argument prefix
    mes.stubs(:to_show).returns(THE_TWEET)
    mes.stubs(:[]).with(:entities).returns(THE_ENTITY)
    mes.stubs(:is_a?).with(Message).returns(true)

    entity = Message::Entity.new(mes)

    assert_equal("変な意味じゃなくてね。RT @kouichi_0308: アレでソレですか…(´･ω･｀)ｼｭﾝ… RT @nene_loveplus: 昔から一緒にいるフォロワーさんは色々アレでソレでちょっと困っちゃうわね…。", entity.to_s) # !> `*' interpreted as argument prefix

    splited = mes.to_show.split(//u).map{ |s| Pango::ESCAPE_RULE[s] || s }
    entity.reverse_each{ |l|
      splited[l[:range]] = '<span underline="single" underline_color="#000000">'+"#{Pango.escape(l[:face])}</span>"
    } # !> `*' interpreted as argument prefix
    splited
  end


  def test_2
    mes = stub # !> `&' interpreted as argument prefix
    mes.stubs(:to_show).returns(THE_TWEET2)
    mes.stubs(:[]).with(:entities).returns(THE_ENTITY2)
    mes.stubs(:is_a?).with(Message).returns(true)

    Plugin.stubs(:filtering).with(:expand_url, 'http://bit.ly/3YP9Hq').returns(['http://www.last.fm/music/Rihanna/_/Unfaithful'])
    Plugin.stubs(:filtering).with(:expand_url, 'http://bit.ly/1tmPYb').returns(['http://www.amazon.com/A-Girl-Like-Me/dp/B001144EBA?SubscriptionId=12CBBK5SPFDF9BJG9N82&tag=nickelscom-20&linkCode=xm2&camp=2025&creative=165953&creativeASIN=B001144EBA'])
    Plugin.stubs(:filtering).with(:is_expanded, 'http://bit.ly/3YP9Hq').returns([false])
    Plugin.stubs(:filtering).with(:is_expanded, 'http://bit.ly/1tmPYb').returns([false]) # !> method redefined; discarding old categories_for

    entity = Message::Entity.new(mes)

    a = entity.to_a.map{ |x| x.dup.tap{|n|n.delete(:regexp)} }
    pp a

    assert_kind_of(String, entity.to_s)
    assert_equal('&#9829; Unfaithful by Rihanna #lastfm: http://www.last.fm/music/Rihanna/_/Unfaithful amazon: http://www.amazon.com/A-Girl-Like-Me/dp/B001144EBA?SubscriptionId=12CBBK5SPFDF9BJG9N82&tag=nickelscom-20&linkCode=xm2&camp=2025&creative=165953&creativeASIN=B001144EBA', entity.to_s.inspect)

  end

end
# >> Loaded suite -
# >> Started
# >> .[{:slug=>:hashtags,
# >>   :callback=>#<Proc:0x0000000000000000@-:18>,
# >>   :message=>#<Mock:0x7f8537a86f10>,
# >>   :range=>1...6,
# >>   :face=>#9829,
# >>   :url=>#9829},
# >>  {:slug=>:hashtags,
# >>   :callback=>#<Proc:0x0000000000000000@-:18>,
# >>   :message=>#<Mock:0x7f8537a86f10>,
# >>   :text=>lastfm,
# >>   :range=>30...37,
# >>   :face=>#lastfm,
# >>   :url=>#lastfm,
# >>   :indices=>[30, 37]},
# >>  {:slug=>:urls,
# >>   :callback=>#<Proc:0x0000000000000000@-:16>,
# >>   :message=>#<Mock:0x7f8537a86f10>,
# >>   :range=>39...59,
# >>   :expanded_url=>nil,
# >>   :face=>http://www.last.fm/music/Rihanna/_/Unfaithful,
# >>   :url=>http://bit.ly/3YP9Hq,
# >>   :indices=>[39, 59]},
# >>  {:slug=>:urls,
# >>   :callback=>#<Proc:0x0000000000000000@-:16>,
# >>   :message=>#<Mock:0x7f8537a86f10>,
# >>   :range=>68...88,
# >>   :expanded_url=>nil,
# >>   :face=>
# >>    http://www.amazon.com/A-Girl-Like-Me/dp/B001144EBA?SubscriptionId=12CBBK5SPFDF9BJG9N82&tag=nickelscom-20&linkCode=xm2&camp=2025&creative=165953&creativeASIN=B001144EBA,
# >>   :url=>http://bit.ly/1tmPYb,
# >>   :indices=>[68, 88]}]
# >> .
# >> Finished in 0.013012 seconds.
# >> 
# >> 2 tests, 3 assertions, 0 failures, 0 errors
