# -*- coding: utf-8 -*-
require 'test/unit'
require 'rubygems'
require 'mocha'
require 'webmock'
require 'gtk2'

Dir.chdir(File.join(File.dirname($0), '../'))
$LOAD_PATH.push '.'
require 'utils'

require 'lib/test_unit_extensions'
miquire :mui, 'web_image_loader'
miquire :core, 'delayer'

class TC_GtkWebImageLoader < Test::Unit::TestCase
  def setup
    Gdk::WebImageLoader::ImageCache.clear
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
    WebMock.stub_request(:get, url).to_return(File.open('test/icon_test.png'){ |io| io.read })
    response = nil
    Gdk::WebImageLoader.pixbuf(url, 48, 48){ |pixbuf, success, url|
      response = [pixbuf, success]
    }
    (Thread.list - [Thread.current]).each &:join
    while not Delayer.empty? do Delayer.run end
    assert_equal(true, Delayer.empty?)
    assert_equal(0, Delayer.size)
    assert_equal(false, response[1])
    response[0].save('test/result.png', 'png')
  end

  must "successfully load local image" do
    url = 'test/result.png'
    response = Gdk::WebImageLoader.pixbuf(url, 48, 48)
    (Thread.list - [Thread.current]).each &:join
    Delayer.run
    assert_not_equal(Gdk::WebImageLoader.loading_pixbuf(48, 48), response)
    assert_not_equal(Gdk::WebImageLoader.notfound_pixbuf(48, 48), response)
  end

  must "local file not found" do
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
      File.open('test/icon_test.png'){ |io| io.read }
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

  must "local path" do
    url = 'http://a0.twimg.com/profile_images/1522298893/itiiti_hitono_icon_no_file_mei_mirutoka_teokure_desune.png'
    WebMock.stub_request(:get, url).to_return(File.open('test/icon_test.png'){ |io| io.read })
    assert_equal("/home/toshi/.mikutter/tmp/e9183b9265dcf0728fceceb07444e8c1.png.png", Gdk::WebImageLoader.local_path(url))
  end

  must "is local path" do
    assert_equal(false, Gdk::WebImageLoader.is_local_path?('http://example.com/a.png'))
    assert_equal(true, Gdk::WebImageLoader.is_local_path?('/path/to/image.png'))
    assert_equal(true, Gdk::WebImageLoader.is_local_path?('test.png'))
    assert_equal(true, Gdk::WebImageLoader.is_local_path?('file:///path/to/image.png'))
    assert_equal(false, Gdk::WebImageLoader.is_local_path?('https://example.com/a.png')) end

end
