# -*- coding: utf-8 -*-

miquire :core, "userconfig", "plugin"

module Skin
  class SkinError < RuntimeError; end
  class FileNotFoundError < SkinError; end
  class ModelNotFoundError < SkinError; end

  extend self
  extend Gem::Deprecate

  SKIN_ROOT = File.join(CHIConfig::CONFROOT, "skin")
  USER_SKIN = if :vanilla == UserConfig[:skin_dir]
                nil
              else
                UserConfig[:skin_dir] end
  AVAILABLE_EXTENSIONS = %w[svg png jpg jpeg].map{|ext| [ext.downcase, ext.upcase] }.flatten.freeze

  def default_dir
    File.join(__dir__, "skin", "data")
  end

  def default_image
    File.join(default_dir, "notfound.png")
  end

  def user_dir
    if USER_SKIN
      File.join(SKIN_ROOT, USER_SKIN)
    else
      nil
    end
  end

  def path
    user_dir || default_dir
  end

  # 現在のSkinにおける、 _filename_ の画像を示すPhoto Modelを取得する
  # ==== Args
  # [filename] 画像ファイル名
  # [fallback_dirs] スキンディレクトリのリスト
  # ==== Return
  # [Diva::Mixin::PhotoMixin] 画像
  # ==== Raises
  # [Skin::FileNotFoundError] 画像 _filename_ が見つからなかった時
  def photo(filename, fallback_dirs=[])
    result = Plugin::Skin::Image[get_path(filename, fallback_dirs)]
    raise FileNotFoundError, "File `#{filename}' does not exists." unless result
    result
  end
  alias :[] :photo

  def get_path(filename, fallback_dirs = [])
    ext = File.extname(filename.to_s)
    if ext.empty?
      get_path_without_extension(filename.to_s, fallback_dirs)
    else
      get_path_with_extension(filename.to_s, fallback_dirs)
    end
  end
  alias :get :get_path
  deprecate :get, "get_path", 2018, 1 if Environment::VERSION >= [3, 6]

  def get_path_with_extension(filename, fallback_dirs)
    filename, fallback_dirs = Plugin.filtering(:skin_get, filename, fallback_dirs)
    [ user_dir, fallback_dirs, default_dir ].flatten.compact.flat_map { |dir|
      File.join(dir, filename)
    }.find { |path|
      FileTest.exist?(path)
    } || default_image
  end

  def get_path_without_extension(filename, fallback_dirs)
    AVAILABLE_EXTENSIONS.lazy.map { |ext|
      get_path_with_extension("#{filename}.#{ext}", fallback_dirs)
    }.find{ |ext|
      ext != default_image
    } || default_image
  end
end
