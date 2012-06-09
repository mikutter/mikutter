# -*- coding: utf-8 -*-
require 'test/unit'
require 'mocha'
require File.expand_path(File.dirname(__FILE__) + '/../lib/test_unit_extensions')
require File.expand_path(File.dirname(__FILE__) + '/../utils')
miquire :core, 'message'
miquire :core, 'service'

$debug = false
# seterrorlevel(:notice)
$logfile = nil
$daemon = false
Plugin = Class.new do
  def self.filtering(*args)
    args[1, args.size] end
end

class TC_Message < Test::Unit::TestCase
  def setup
    user_obj = {
      id: 164348251,
      name: "mikutter_bot",
      idname: "mikutter_bot" }
    user = User.new_ifnecessary( user_obj )
    Service.any_instance.stubs(:user_initialize).returns(user)
    @service ||= Service.new
  end # !> ambiguous first argument; put parentheses or even spaces

  must "hierarchy check" do
    toshi = User.new_ifnecessary(:id => 123456, :idname => 'toshi_a', :name => 'toshi')
    miku = User.new_ifnecessary(:id => 393939, :idname => 'ha2ne39', :name => 'miku')
    c1 = Message.new_ifnecessary(:id => 11, :message => '@ha2ne39 hey, miku!', :user => toshi, :created => Time.now)
    c2 = Message.new_ifnecessary(:id => 12, :message => '@toshi_a hi master, how r u?', :user => miku, :replyto =>c1, :created => Time.now)
    c3 = Message.new_ifnecessary(:id => 13, :message => '@toshi_a i happy. because u r cute!', :user => toshi, :replyto =>c2, :created => Time.now)
    c4 = Message.new_ifnecessary(:id => 14, :message => '@ha2ne39...baka///', :user => miku, :replyto =>c3, :created => Time.now)
    c5 = Message.new_ifnecessary(:id => 15, :message => '@toshi_a inhibit ashamed words!', :user => miku, :replyto =>c3, :created => Time.now)
    assert_equal(c1, c2.receive_message)
    assert_kind_of(Message, c2.receive_message)
    assert_kind_of(Message, c1) # !> method redefined; discarding old inspect
    assert_equal(true, c1.children.include?(c2))

    assert_instance_of Set, c2.children
    assert_equal c2.receive_message, c1
    assert_equal c3.receive_message, c2
    Plugin.stubs(:filtering).with(:replied_by, c3, Set.new).returns([c3, [c4, c5]])
    Plugin.stubs(:filtering).with(:retweeted_by, c3, Set.new).returns([c3, []])
    c3children = c3.children
    assert c3children.include?(c4)
    assert c3children.include?(c5)
    assert !c3children.include?(c2)
    assert_equal c4.receive_message, c3
  end

  must "receive user detect" do
    toshi = User.new_ifnecessary(:id => 123456, :idname => 'toshi_a', :name => 'toshi')
    message = Message.new_ifnecessary(:id => 11, :message => '@ha2ne39 @mikutter_bot hey, miku!', :user => toshi, :created => Time.now)
    assert_equal ["ha2ne39", "mikutter_bot"], message.receive_user_screen_names
  end

  must "receive user not detect" do
    toshi = User.new_ifnecessary(:id => 123456, :idname => 'toshi_a', :name => 'toshi')
    message = Message.new_ifnecessary(:id => 11, :message => 'nemui', :user => toshi, :created => Time.now)
    assert message.receive_user_screen_names.empty?
  end

end
# ~> notice: ./post.rb:61:in `initialize': -:14:in `new'
# ~> ./retriever.rb:345: warning: instance variable @time not initialized
# ~> ./retriever.rb:345: warning: instance variable @time not initialized
# ~> ./delayer.rb:60: warning: instance variable @busy not initialized
# ~> ./delayer.rb:60: warning: instance variable @busy not initialized
# ~> ./delayer.rb:60: warning: instance variable @busy not initialized
# >> Loaded suite -
# >> Started
# >> .
# >> Finished in 0.006363 seconds.
# >> 
# >> 1 tests, 11 assertions, 0 failures, 0 errors
