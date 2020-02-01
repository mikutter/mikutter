# -*- coding: utf-8 -*-

=begin rdoc
Model用のmoduleで、これをincludeするとUserに要求されるいくつかのメソッドが定義される。
=end
module Diva::Model::UserMixin
  def user
    self
  end

  def icon
    Plugin.collect(:photo_filter, profile_image_url, Pluggaloid::COLLECT).map { |photo|
      Plugin.filtering(:miracle_icon_filter, photo)[0]
    }.first
  end

  def icon_large
    Plugin.collect(:photo_filter, profile_image_url_large, Pluggaloid::COLLECT).lazy.map { |photo|
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
