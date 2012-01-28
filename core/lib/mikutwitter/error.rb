# -*- coding: utf-8 -*-

require "mikutwitter/basic"

class MikuTwitter::Error < StandardError
  attr_accessor :httpresponse

  def initialize(text, httpresponse)
    super(text)
    @httpresponse = httpresponse
  end
end
