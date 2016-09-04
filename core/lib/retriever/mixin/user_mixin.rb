# -*- coding: utf-8 -*-

=begin rdoc
Model用のmoduleで、これをincludeするとUserに要求されるいくつかのメソッドが定義される。
=end
module Retriever::Model::UserMixin
  def user
    self
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
