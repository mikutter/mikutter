# -*- coding: utf-8 -*-

require 'test/unit'
require 'rubygems'
require 'mocha'
require File.expand_path(File.dirname(__FILE__) + '/../lib/test_unit_extensions')
require File.expand_path(File.dirname(__FILE__) + '/../utils')
miquire :core, 'post'

class TC_Post < Test::Unit::TestCase

  KEY = 'KEY1234'
  SECRET = 'SECRET1234'

  def setup
  end

  must "following" do
    twitter = Class.new

    UserConfig.stubs(:[]).with(:twitter_token).returns(KEY)
    UserConfig.stubs(:[]).with(:twitter_secret).returns(SECRET)
    UserConfig.stubs(:[]).with(:twitter_authenticate_revision).returns(Environment::TWITTER_AUTHENTICATE_REVISION)
    Twitter.stubs(:new).with(KEY, SECRET).returns(twitter)
    Post::MessageServiceRetriever.stubs(:new).returns(:msr)
    Message.stubs(:add_data_retriever).with(:msr).returns(nil)
    Post::UserServiceRetriever.stubs(:new).returns(:usr)
    User.stubs(:add_data_retriever).with(:usr).returns(nil)
    service = Post.new
    service.stubs(:inspect).returns("#<Post: test>")
    service.stubs(:user).returns(User.system)
    service.stubs(:scan).with(:followers,
                              :id => User.system,
                              :get_raw_text => true,
                              :cache => false,
                              :cursor => -1).returns([[User.system], {:next_cursor => 0}])
    service.followers{ |result|
      assert_equal([User.system], result)
    }
  end

end
