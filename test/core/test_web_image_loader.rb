# -*- coding: utf-8 -*-
require 'test/unit'
require 'rubygems'
require 'mocha'
require 'webmock'
require 'gtk2'

ICON_TEST = File.expand_path(File.dirname(__FILE__) + "/icon_test.png")
require File.expand_path(File.dirname(__FILE__) + '/../../core/utils')

require 'lib/test_unit_extensions'
miquire :mui, 'web_image_loader'
miquire :core, 'delayer'

Plugin = Class.new do
  def self.call(*args); end
end

class TC_GtkWebImageLoader < Test::Unit::TestCase

  def setup
    Gdk::WebImageLoader::ImageCache.clear
    urls = ['http://a0.twimg.com/profile_images/1522298893/itiiti_hitono_icon_no_file_mei_mirutoka_teokure_desune.png',
            'http://a0.twimg.com/profile_images/1522298893/みくかわいい.png',
            'http://internal.server.error/',
            'http://notfound/']
    urls.each{ |u|
      Plugin.stubs(:filtering).with(:image_cache, u, nil).returns([u, nil]) }
    urls.each{ |u|
      Plugin.stubs(:filtering).with(:web_image_loader_url_filter, u, nil).returns([u, nil]) }
  end

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
    response = nil
    Gdk::WebImageLoader.pixbuf('http://internal.server.error/', 48, 48){ |pixbuf, success, url|
      response = [pixbuf, success]
    }
    (Thread.list - [Thread.current]).each &:join
    Delayer.run
    assert_equal(true, response[1])
    assert_kind_of(Gdk::Pixbuf, response[0])
  end

  must "successfully load image" do
    url = 'http://a0.twimg.com/profile_images/1522298893/itiiti_hitono_icon_no_file_mei_mirutoka_teokure_desune.png'
    WebMock.stub_request(:get, url).to_return(File.open(ICON_TEST){ |io| io.read })
    response = nil
    Gdk::WebImageLoader.pixbuf(url, 48, 48){ |pixbuf, success, url|
      response = [pixbuf, success]
    }
    (Thread.list - [Thread.current]).each &:join
    while not Delayer.empty? do Delayer.run end
    assert_equal(true, Delayer.empty?)
    assert_equal(0, Delayer.size)
    assert_equal(nil, response[1])
    # response[0].save('test/result.png', 'png')

    # もう一回ロードしてみる
    response2 = nil
    pb = Gdk::WebImageLoader.pixbuf(url, 48, 48){ |pixbuf, success, url|
      response2 = [pixbuf, success]
    }
    assert_equal(response[0], pb)
  end

  must "load by url included japanese" do
    # URI::InvalidURIError
    # url = 'http://a1.twimg.com/profile_images/80925056/クリップボード01_normal.jpg'
    url = 'http://a0.twimg.com/profile_images/1522298893/みくかわいい.png'
    WebMock.stub_request(:get, url).to_return(File.open(ICON_TEST){ |io| io.read })
    response = nil
    Gdk::WebImageLoader.pixbuf(url, 48, 48){ |pixbuf, success, url|
      response = [pixbuf, success]
    }
    (Thread.list - [Thread.current]).each &:join
    while not Delayer.empty? do Delayer.run end
    assert_equal(true, Delayer.empty?)
    assert_equal(0, Delayer.size)
    assert_equal(nil, response[1])
  end

  must "successfully load local image" do
    url = 'skin/data/icon.png'
    Plugin.stubs(:filtering).with(:web_image_loader_url_filter, url).returns([url])
    response = Gdk::WebImageLoader.pixbuf(url, 48, 48)
    (Thread.list - [Thread.current]).each &:join
    Delayer.run
    assert_not_equal(Gdk::WebImageLoader.loading_pixbuf(48, 48), response, "ローカル画像は絶対にロード中のイメージは返ってこない")
    assert_not_equal(Gdk::WebImageLoader.notfound_pixbuf(48, 48), response, "画像が見つからない")
  end

  must "local file not found" do
    Plugin.stubs(:filtering).with(:web_image_loader_url_filter, 'notfound-file').returns(['notfound-file'])
    response = Gdk::WebImageLoader.pixbuf('notfound-file', 48, 48)
    (Thread.list - [Thread.current]).each &:join
    Delayer.run
    assert_equal(Gdk::WebImageLoader.notfound_pixbuf(48, 48), response)
  end

  must "multi thread load image" do
    url = 'http://a0.twimg.com/profile_images/1522298893/itiiti_hitono_icon_no_file_mei_mirutoka_teokure_desune.png'
    access_count = 0
    WebMock.stub_request(:get, url).to_return{
      atomic{ access_count += 1 }
      File.open(ICON_TEST){ |io| io.read }
    }
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
    assert_equal(1, access_count)
  end

  must "get raw data success" do
    raw = response = nil
    Thread.new {
      url = 'http://a0.twimg.com/profile_images/1522298893/itiiti_hitono_icon_no_file_mei_mirutoka_teokure_desune.png'
      http_raw = File.open(ICON_TEST){ |io| io.read }.force_encoding('ASCII-8BIT').freeze
      raw = http_raw[http_raw.index("\211PNG".force_encoding('ASCII-8BIT')), http_raw.size]
      WebMock.stub_request(:get, url).to_return(http_raw)
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
    Thread.new {
      WebMock.stub_request(:get, url).to_return(File.open(ICON_TEST){ |io| io.read })
      localpath = Gdk::WebImageLoader.local_path(url)
    }.join
    assert_equal("/home/toshi/.mikutter/tmp/e9183b9265dcf0728fceceb07444e8c1.png.png", localpath)
  end

  must "is local path" do
    assert_equal(false, Gdk::WebImageLoader.is_local_path?('http://example.com/a.png'))
    assert_equal(true, Gdk::WebImageLoader.is_local_path?('/path/to/image.png'))
    assert_equal(true, Gdk::WebImageLoader.is_local_path?('test.png'))
    assert_equal(true, Gdk::WebImageLoader.is_local_path?('file:///path/to/image.png'))
    assert_equal(false, Gdk::WebImageLoader.is_local_path?('https://example.com/a.png')) end

end
