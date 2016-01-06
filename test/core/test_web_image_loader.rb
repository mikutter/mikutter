# -*- coding: utf-8 -*-
require File.expand_path(File.dirname(__FILE__) + '/../helper')

require 'webmock/test_unit'
require 'gtk2'

ICON_TEST = File.expand_path(File.dirname(__FILE__) + "/icon_test.png")

miquire :mui, 'web_image_loader'
miquire :lib, 'delayer'
miquire :core, 'plugin'

class TC_GtkWebImageLoader < Test::Unit::TestCase

  def setup
    Gdk::WebImageLoader::ImageCache.clear end

  must "not found" do
    WebMock.stub_request(:get, "notfound").to_return(:status => 404)
    response = nil
    Gdk::WebImageLoader.pixbuf('http://notfound/', 48, 48){ |pixbuf, success, url|
      response = [pixbuf, success]
    }
    (Thread.list - [Thread.current]).each &:join
    Delayer.run
    assert_equal(true, response[1])
    assert_kind_of(Gdk::Pixbuf, response[0])
  end

  must "internal server error" do
    WebMock.stub_request(:get, "internal.server.error").to_return(:status => 404)
    response_pixbuf = response_success = nil
    Gdk::WebImageLoader.pixbuf('http://internal.server.error/', 48, 48){ |pixbuf, success, url|
      response_pixbuf, response_success = [pixbuf, success]
    }
    (Thread.list - [Thread.current]).each &:join
    Delayer.run(0)
    assert_equal(true, response_success)
    assert_kind_of(Gdk::Pixbuf, response_pixbuf)
  end

  must "successfully load image" do
    url = 'http://a0.twimg.com/profile_images/1522298893/itiiti_hitono_icon_no_file_mei_mirutoka_teokure_desune.png'
    stub_request(:get, url).
      to_return(
        status: 200,
        body: File.new(ICON_TEST, 'rb'))
    response_pixbuf = response_success = nil
    Gdk::WebImageLoader.pixbuf(url, 48, 48){ |pixbuf, success, url|
      response_pixbuf, response_success = [pixbuf, success]
    }
    (Thread.list - [Thread.current]).each &:join
    while not Delayer.empty? do Delayer.run end
    assert_equal(true, Delayer.empty?)
    assert_equal(0, Delayer.size)
    assert_equal(nil, response_success)

    # もう一回ロードしてみる
    assert_equal(response_pixbuf, Gdk::WebImageLoader.pixbuf(url, 48, 48))
  end

  must "load by url included japanese" do
    # URI::InvalidURIError
    # url = 'http://a1.twimg.com/profile_images/80925056/クリップボード01_normal.jpg'
    url = 'http://a0.twimg.com/profile_images/1522298893/みくかわいい.png'
    stub_request(:get, url).
      to_return(
        status: 200,
        body: File.new(ICON_TEST, 'rb'))
    response = nil
    Gdk::WebImageLoader.pixbuf(url, 48, 48){ |pixbuf, success, url|
      response = success
    }
    (Thread.list - [Thread.current]).each &:join
    while not Delayer.empty? do Delayer.run end
    assert_equal(true, Delayer.empty?)
    assert_equal(0, Delayer.size)
    assert_equal(nil, response)
  end

  must "successfully load local image" do
    url = File.join(File.dirname(__FILE__), '../../core/skin/data/icon.png')
    response = Gdk::WebImageLoader.pixbuf(url, 48, 48)
    (Thread.list - [Thread.current]).each &:join
    Delayer.run
    assert_not_equal(Gdk::WebImageLoader.loading_pixbuf(48, 48), response, "ローカル画像は絶対にロード中のイメージは返ってこない")
    assert_not_equal(Gdk::WebImageLoader.notfound_pixbuf(48, 48), response, "画像が見つからない")
  end

  must "local file not found" do
    response = Gdk::WebImageLoader.pixbuf('notfound-file', 48, 48)
    (Thread.list - [Thread.current]).each &:join
    Delayer.run
    assert_equal(Gdk::WebImageLoader.notfound_pixbuf(48, 48), response)
  end

  must "multi thread load image" do
    url = 'http://a0.twimg.com/profile_images/1522298893/itiiti_hitono_icon_no_file_mei_mirutoka_teokure_desune.png'
    stub_request(:get, url).
      to_return(
        status: 200,
        body: File.new(ICON_TEST, 'rb')).then.
      to_raise(RuntimeError)
    response = Array.new(20)
    20.times{ |cnt|
      response[cnt] = Gdk::WebImageLoader.pixbuf(url, 48, 48){ |pixbuf|
        response[cnt] = pixbuf
      }
    }
    (Thread.list - [Thread.current]).each &:join
    until Delayer.empty? do Delayer.run end
    assert_equal(true, Delayer.empty?)
    assert_equal(0, Delayer.size)

    response.each { |r|
      assert_kind_of(Gdk::Pixbuf, r)
      assert_not_equal(Gdk::WebImageLoader.loading_pixbuf(48, 48), r)
      assert_not_equal(Gdk::WebImageLoader.notfound_pixbuf(48, 48), r) }
  end

  must "get raw data success" do
    raw = response = nil
    Thread.new {
      url = 'http://a0.twimg.com/profile_images/1522298893/itiiti_hitono_icon_no_file_mei_mirutoka_teokure_desune.png'
      raw = File.open(ICON_TEST, 'rb'){ |io| io.read }.force_encoding('ASCII-8BIT').freeze
      stub_request(:get, url).
        to_return(
          status: 200,
          body: raw)
      Gdk::WebImageLoader.get_raw_data(url){ |data, success, url|
        response = [data, success] } }.join
    (Thread.list - [Thread.current]).each &:join
    while not Delayer.empty? do Delayer.run end
    assert_equal(true, Delayer.empty?)
    assert_equal(0, Delayer.size)
    assert_equal(raw, response[0])
  end

  must "local path" do
    localpath = nil
    url = 'http://a0.twimg.com/profile_images/1522298893/itiiti_hitono_icon_no_file_mei_mirutoka_teokure_desune.png'
    stub_request(:get, url).
      to_return(
        status: 200,
        body: File.new(ICON_TEST, 'rb'))
    Thread.new {
      localpath = Gdk::WebImageLoader.local_path(url)
    }.join
    assert_equal(File.join(Environment::TMPDIR, "e9183b9265dcf0728fceceb07444e8c1.png.png"), localpath)
  end

  must "is local path" do
    assert_equal(false, Gdk::WebImageLoader.is_local_path?('http://example.com/a.png'))
    assert_equal(true, Gdk::WebImageLoader.is_local_path?('/path/to/image.png'))
    assert_equal(true, Gdk::WebImageLoader.is_local_path?('test.png'))
    assert_equal(true, Gdk::WebImageLoader.is_local_path?('file:///path/to/image.png'))
    assert_equal(false, Gdk::WebImageLoader.is_local_path?('https://example.com/a.png')) end

end
