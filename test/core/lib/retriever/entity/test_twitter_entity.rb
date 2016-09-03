# -*- coding: utf-8 -*-

require_relative '../../../../helper'

miquire :lib, 'retriever'

class TC_TwitterEntity < Test::Unit::TestCase
  class EntityTestModel < Retriever::Model
    field.string :message, required: true
    field.time   :created
    field.time   :modified

    entity_class Retriever::Entity::TwitterEntity

    def to_show
      self[:message]
    end
  end

  def setup
  end

  # 2つ目以降のEntityの位置がずれる問題
  def test_nested_legacy_retweet
    model = EntityTestModel.new(
      message: '変な意味じゃなくてね。RT @kouichi_0308: アレでソレですか…(´･ω･｀)ｼｭﾝ… RT @nene_loveplus: 昔から一緒にいるフォロワーさんは色々アレでソレでちょっと困っちゃうわね…。',
      entities: {
        user_mentions: [ { id_str: "127914421",
                           screen_name: "kouichi_0308",
                           name: "コウイチ(2011年度版)",
                           id: 127914421,
                           indices: [14, 27]},
                         { id_str: "95126742",
                           screen_name: "nene_loveplus",
                           name: "姉ヶ崎寧々",
                           id: 95126742,
                           indices: [53, 67]}],
        urls: [],
        hashtags: [] })
    assert_equal model[:message], model.entity.to_s
  end

  # TwitterがEntityを返さないという勘弁してほしいケース
  def test_lost_entity
    model = EntityTestModel.new(
      message: 'RT @toshi_a: おいmikutterが変態ツイッタークライアントだという風説が',
      entities: {})
    assert_equal model[:message], model.entity.to_s
  end

  def test_mention_no_space_splitted
    model = EntityTestModel.new(
      message: 'もともとは@penguin2716さんに勧められて始めたついった。そして彼より遅く始めた自分がTwitterにハマり、彼の総ポスト数をすぐに追い抜いたと思ったのですが、今や彼はれっきとしたmikutter廃人となり、ワタシの手の届かぬ領域に到達されました。',
      entities: {})
    assert_equal model[:message], model.entity.to_s
  end

  # >のあとに@...があるケース。エンティティエンコードのせいで位置がずれてないか
  def test_segment_after_escaped_character
    model = EntityTestModel.new(
      message: '一体何をやってんだろう(笑)。 > @toshi_a the hacker',
      entities: {
        hashtags: [],
        urls: [],
        user_mentions: [
          { name: "蝶舞スカーフ型としぁ",
            screen_name: "toshi_a",
            indices: [21, 29],
            id: 15926668,
            id_str: "15926668"}]})
    assert_equal model[:message], model.entity.to_s
  end

  # URLのあとにハッシュタグがある
  def test_mixed_entities
    model = EntityTestModel.new(
      message: 'まだまだ絶賛配信中！今日は「日常のラヂオ」第３５回がランティスネットラジオ goo.gl/2tsIG にて２２時から配信スタートです！「日常」が好きな人ならきっと楽しんでいただけますのでよろしくお願いします。 #nichijou',
      entities: {
        user_mentions: [],
        urls: [
          { url: "goo.gl/2tsIG",
            indices: [38, 50],
            expanded_url: nil } ],
        hashtags: [
          { indices: [105, 114],
            text: "nichijou" } ]})
    assert_equal model[:message], model.entity.to_s
  end

  # まじでいらん機能によってエンティティの計算がずれていないか
  def test_cashtags
    model = EntityTestModel.new(
      message: "@uebayasi I tried and it works as below:\n$ uname -srm\nNetBSD 6.0.1 amd64\n$  s ( ) { local b; b=1; echo $b; b=\"$@\"; echo $b; }\n$ s d e\n1\nd e",
      entities: {
        hashtags: [], 
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
    assert_equal model[:message], model.entity.to_s
  end

  # TwitterがEntityを返さないという勘弁してほしいケース
  def test_has_media
    model = EntityTestModel.new(
      message: "【特価品】Celeron C1037U&HM77、デュアルLAN(82574L)を搭載したNAS向miniITXマザー Giada N70E-DR V2 14980円 http://t.co/zYaNWyebgm https://t.co/DCbLaYFXeu",
      entities: {
        hashtags: [],
        symbols: [],
        urls: 
          [{ url: "http://t.co/zYaNWyebgm",
             expanded_url: "http://goo.gl/HDK5i",
             display_url: "goo.gl/HDK5i",
             indices: [88, 110]}],
        user_mentions: [],
        media: 
          [{ id: 352644565880168448,
             id_str: "352644565880168448",
             indices: [111, 134],
             media_url: "http://pbs.twimg.com/media/BOTYXUFCYAAGmf_.jpg",
             media_url_https: "https://pbs.twimg.com/media/BOTYXUFCYAAGmf_.jpg",
             url: "https://t.co/DCbLaYFXeu",
             display_url: "pic.twitter.com/DCbLaYFXeu",
             expanded_url: 
               "http://twitter.com/ph_toei/status/352644565875974144/photo/1",
             type: "photo",
             sizes: 
               { medium: {w: 480, h: 437, resize: "fit"},
                 thumb: {w: 150, h: 150, resize: "crop"},
                 small: {w: 340, h: 310, resize: "fit"},
                 large: {w: 480, h: 437, resize: "fit"}},
             source_status_id: 352644565875974144,
             source_status_id_str: "352644565875974144"}]})
    assert_equal "【特価品】Celeron C1037U&HM77、デュアルLAN(82574L)を搭載したNAS向miniITXマザー Giada N70E-DR V2 14980円 goo.gl/HDK5i pic.twitter.com/DCbLaYFXeu", model.entity.to_s
  end


end
