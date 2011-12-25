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
miquire :mui, 'webicon'

class TC_GtkWebIcon < Test::Unit::TestCase
  def setup
  end

  must "local image load" do
    image = Gtk::WebIcon.new('test/result.png', 48, 48)
    assert_kind_of(Gdk::Pixbuf, image.pixbuf)
    assert_not_equal(Gdk::WebImageLoader.loading_pixbuf(48, 48), image.pixbuf)
    assert_not_equal(Gdk::WebImageLoader.notfound_pixbuf(48, 48), image.pixbuf)
    image.pixbuf.save('test/result2.png', 'png')
  end

  must "local image not found" do
    image = Gtk::WebIcon.new('notfound-file', 48, 48)
    assert_kind_of(Gdk::Pixbuf, image.pixbuf)
    assert_equal(Gdk::WebImageLoader.notfound_pixbuf(48, 48), image.pixbuf)
  end

end
