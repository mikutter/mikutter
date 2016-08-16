# -*- coding: utf-8 -*-
require File.expand_path(File.dirname(__FILE__) + '/../helper')
miquire :core, 'message'
miquire :core, 'service'

$debug = false
# seterrorlevel(:notice)
$logfile = nil
$daemon = false
Plugin = Class.new do
  def self.call(*args); end
  def self.filtering(*args)
    args[1, args.size] end
end

class TC_Message < Test::Unit::TestCase
  def setup
  end # !> ambiguous first argument; put parentheses or even spaces

  must "hierarchy check" do
    toshi = User.new(:id => 123456, :idname => 'toshi_a', :name => 'toshi')
    miku = User.new(:id => 393939, :idname => 'ha2ne39', :name => 'miku')
    c1 = Message.new(:id => 11, :message => '@ha2ne39 みくちゃああああああああああああん', :user => toshi, :created => Time.now)
    c2 = Message.new(:id => 12, :message => '@toshi_a なに', :user => miku, :replyto =>c1, :created => Time.now)
    c3 = Message.new(:id => 13, :message => '@ha2ne39 ぺろぺろぺろぺろ（＾ω＾）', :user => toshi, :replyto =>c2, :created => Time.now)
    c4 = Message.new(:id => 14, :message => '@toshi_a 垢消せ', :user => miku, :replyto =>c3, :created => Time.now)
    c5 = Message.new(:id => 15, :message => '@toshi_a キモい', :user => miku, :replyto =>c3, :created => Time.now)
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

  must "around check" do
    toshi = User.new(:id => 123456, :idname => 'toshi_a', :name => 'toshi')
    miku = User.new(:id => 393939, :idname => 'ha2ne39', :name => 'miku')
    c1 = Message.new(:id => 21, :message => 'おはよう', :user => toshi, :created => Time.now)
    c2 = Message.new(:id => 22, :message => '@toshi_a おはよう', :user => miku, :replyto =>c1, :created => Time.now)
    c3 = Message.new(:id => 23, :message => '@ha2ne39 ぺろぺろぺろぺろ（＾ω＾）', :user => toshi, :replyto =>c2, :created => Time.now)
    c4 = Message.new(:id => 24, :message => '@toshi_a おはよう', :user => toshi, :replyto =>c1, :created => Time.now)
    c1.children << c2
    c2.children << c3
    c1.children << c4
    assert_equal [21, 22, 23, 24], c2.around.map(&:id).sort
    assert_equal [22, 23], c2.children_all.map(&:id).sort
  end

  must "receive user detect" do
    toshi = User.new(:id => 123456, :idname => 'toshi_a', :name => 'toshi')
    message = Message.new(:id => 11, :message => '@ha2ne39 @mikutter_bot hey, miku!', :user => toshi, :created => Time.now)
    assert_equal '@ha2ne39 @mikutter_bot hey, miku!', message[:message]
    assert_equal ["ha2ne39", "mikutter_bot"], message.receive_user_screen_names
  end

  must "receive user not detect" do
    toshi = User.new(:id => 123456, :idname => 'toshi_a', :name => 'toshi')
    message = Message.new(:id => 11, :message => 'nemui', :user => toshi, :created => Time.now)
    assert message.receive_user_screen_names.empty?
  end

  must "message to me" do
    toshi = User.new(:id => 156, :idname => 'toshi', :name => 'toshi')
    toshi_a = User.new(:id => 123456, :idname => 'toshi_a', :name => 'toshi_a')
    toshi_b = User.new(:id => 1234567, :idname => 'toshi_b', :name => 'toshi_b')
    toshi_a_a = User.new(:id => 156156, :idname => 'toshi_a_a', :name => 'toshi_a_a')
    message = Message.new(id: 11, message: "krile で where user == @toshi_a | user == @toshi_a_a だけのタブ作っただけでわずかにタブ切り替えが遅くなってるのわかると思うしアカウント切り替えは極端に遅くなってる", user: toshi, created: Time.now, receiver: toshi_b)
    assert !message.receive_to?(toshi), 'toshi宛てのメッセージではない'
    assert message.receive_to?(toshi_a), 'toshi_a宛てのメッセージ'
    assert message.receive_to?(toshi_a_a), 'toshi_a_a宛てのメッセージ'
    assert message.receive_to?(toshi_b), 'toshi_b宛てのメッセージ'
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
