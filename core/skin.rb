# -*- coding: utf-8 -*-

miquire :core, "userconfig"

class Skin
  SKIN_ROOT = File.join(CHIConfig::CONFROOT, "skin")
  USER_SKIN = if :vanilla == UserConfig[:skin_dir]
                nil
              else
                UserConfig[:skin_dir] end

  def self.default_dir
    File.join(*[File.dirname(__FILE__), "skin", "data"].flatten)
  end

  def self.default_image
    File.join(default_dir, "notfound.png")
  end

  def self.user_dir
    if USER_SKIN
      File.join(SKIN_ROOT, USER_SKIN)
    else
      nil
    end
  end

  def self.get(filename, fallback_dirs = [])
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
end
