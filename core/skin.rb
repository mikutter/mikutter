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

  def default_dir
    File.join(*[File.dirname(__FILE__), "skin", "data"].flatten)
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
  # [Retriever::Mixin::PhotoMixin] 画像
  # ==== Raises
  # [Skin::FileNotFoundError] 画像 _filename_ が見つからなかった時
  def photo(filename, fallback_dirs=[])
    result = Plugin::Skin::Image[get_path(filename, fallback_dirs)]
    raise FileNotFoundError, "File `#{filename}' does not exists." unless result
    result
  end
  alias :[] :photo

  def get_path(filename, fallback_dirs = [])
    filename, fallback_dirs = Plugin.filtering(:skin_get, filename, fallback_dirs)
    search_path = [ user_dir, fallback_dirs, default_dir ].flatten.compact

    valid_path = search_path.map { |_|
      File.join(_, filename)
    }.select { |_|
      FileTest.exist?(_)
    }.first

    if valid_path
      valid_path
    else
      default_image
    end
  end
  alias :get :get_path
  deprecate :get, "get_path", 2018, 1 if Environment::VERSION >= [3, 6]

end
