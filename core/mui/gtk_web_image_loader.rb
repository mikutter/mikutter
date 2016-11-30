# -*- coding: utf-8 -*-
# 画像のURLを受け取って、Gtk::Pixbufを返す

miquire :core, 'serialthread', 'skin'
miquire :lib, 'addressable/uri'
require 'net/http'
require 'uri'
require 'thread'
require 'fileutils'

module Gdk::WebImageLoader
  extend Gdk::WebImageLoader
  extend Gem::Deprecate

  # mikutter 3.5から、このメソッドはDeprecateです。
  # 今後は、次のようなコードを書いてください。
  # ==== Example
  #   photo = Plugin.filtering(:photo_filter, url, []).last.first
  #   photo.load_pixbuf(width: width, height: height, &load_callback)
  def pixbuf(url, width, height = nil, &load_callback)
    if width.respond_to?(:width) and width.respond_to?(:height)
      width, height = width.width, width.height
    end
    if load_callback
      Enumerator.new{|y|
        Plugin.filtering(:photo_filter, url, y)
      }.first.load_pixbuf(width: width, height: height, &load_callback)
    else
      Enumerator.new{|y|
        Plugin.filtering(:photo_filter, url, y)
      }.first.pixbuf(width: width, height: height) ||
        Skin['notfound.png'].pixbuf(width: width, height: height)
    end
  end
  deprecate :pixbuf, "Retriever::Model::PhotoMixin#load_pixbuf", 2018, 1 if Environment::VERSION >= [3, 6]

  # mikutter 3.5から、このメソッドはDeprecateです。
  def local_path(url, width = 48, height = width)
    url.freeze
    ext = (File.extname(url).split("?", 2)[0] or File.extname(url))
    filename = File.expand_path(File.join(Environment::TMPDIR, Digest::MD5.hexdigest(url + "#{width}x#{height}") + ext + '.png'))
    pb = pixbuf(url, width, height)
    if(pb)
      pb.save(filename, 'png') if not FileTest.exist?(filename)
      local_path_files_add(filename)
      filename end end
  deprecate :local_path, :none, 2018, 1 if Environment::VERSION >= [3, 6]

  # mikutter 3.5から、このメソッドはDeprecateです。
  # 今後は、次のようなコードを書いてください。
  # ==== Example
  #   photo = Plugin.filtering(:photo_filter, url, []).last.first
  #   photo.download.next(&load_callback).trap{|exception|
  #     # ダウンロードに失敗した時に呼ばれる
  #   }
  def get_raw_data(url, &load_callback) # :yield: raw, exception, url
    result = Enumerator.new{|y|
      Plugin.filtering(:photo_filter, url, y)
    }.blob
    if result
      result
    else
      Enumerator.new{|y|
        Plugin.filtering(:photo_filter, url, y)
      }.download do |photo|
        load_callback.(photo.blob)
      end
      :wait
    end
  end
  deprecate :get_raw_data, "Retriever::Model::PhotoMixin#download", 2018, 1 if Environment::VERSION >= [3, 6]

  # mikutter 3.5から、このメソッドはDeprecateです。
  # 今後は、次のようなコードを書いてください。
  # ==== Example
  #   photo = Plugin.filtering(:photo_filter, url, []).last.first
  #   photo.download
  def get_raw_data_d(url)
    Enumerator.new{|y|
      Plugin.filtering(:photo_filter, url, y)
    }.download.next{|photo| photo.blob }
  end
  deprecate :get_raw_data_d, "Retriever::Model::PhotoMixin#download", 2018, 1 if Environment::VERSION >= [3, 6]

  # mikutter 3.5から、このメソッドはDeprecateです。
  def is_local_path?(url)
    not url.start_with?('http') end
  deprecate :is_local_path?, :none, 2018, 1 if Environment::VERSION >= [3, 6]

  # mikutter 3.5から、このメソッドはDeprecateです。
  # 今後は、次のようなコードを書いてください。
  # ==== Example
  #   Skin['loading.png'].pixbuf(width: width, height: height)
  def loading_pixbuf(rect, height = nil)
    if height
      Skin['loading.png'].pixbuf(width: rect, height: height)
    else
      Skin['loading.png'].pixbuf(width: rect.width, height: rect.height)
    end
  end
  deprecate :loading_pixbuf, 'Skin[\'loading.png\'].pixbuf(width: width, height: height)', 2018, 1 if Environment::VERSION >= [3, 6]

  # mikutter 3.5から、このメソッドはDeprecateです。
  # 今後は、次のようなコードを書いてください。
  # ==== Example
  #   Skin['notfound.png'].pixbuf(width: width, height: height)
  def notfound_pixbuf(rect, height = nil)
    if height
      Skin['notfound.png'].pixbuf(width: rect, height: height)
    else
      Skin['notfound.png'].pixbuf(width: rect.width, height: rect.height)
    end
  end
  deprecate :notfound_pixbuf, 'Skin[\'notfound.png\'].pixbuf(width: width, height: height)', 2018, 1 if Environment::VERSION >= [3, 6]
  private

  def local_path_files_add(path)
    atomic{
      if not defined?(@local_path_files)
        @local_path_files = Set.new
        at_exit{ FileUtils.rm(@local_path_files.to_a) } end }
    @local_path_files << path
  end
end

module Gdk
  deprecate_constant :WebImageLoader if respond_to?(:deprecate_constant) and Environment::VERSION >= [3, 6]
end
