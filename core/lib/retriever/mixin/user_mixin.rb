# -*- coding: utf-8 -*-

=begin rdoc
Model用のmoduleで、これをincludeするとUserに要求されるいくつかのメソッドが定義される。
=end
module Retriever::Model::UserMixin
  def user
    self
  end

  memoize def icon
    Retriever::Model(:photo)[profile_image_url]
  end

  memoize def icon_large
    Retriever::Model(:photo)[profile_image_url_large]
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
