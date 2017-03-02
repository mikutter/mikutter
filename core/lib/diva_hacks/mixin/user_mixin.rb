# -*- coding: utf-8 -*-

=begin rdoc
Model用のmoduleで、これをincludeするとUserに要求されるいくつかのメソッドが定義される。
=end
module Diva::Model::UserMixin
  def user
    self
  end

  def icon
    Enumerator.new{|y|
      Plugin.filtering(:photo_filter, profile_image_url, y)
    }.map{|photo|
      Plugin.filtering(:miracle_icon_filter, photo)[0]
    }.first
  end

  def icon_large
    Enumerator.new{|y|
      Plugin.filtering(:photo_filter, profile_image_url_large, y)
    }.map{|photo|
      truth = Plugin.filtering(:miracle_icon_filter, photo)[0]
      if photo == truth
        truth
      else
        icon
      end
    }.first
  end

  def profile_image_url_large
    profile_image_url
  end

  def verified?
    false
  end

  def protected?
    false
  end
end
