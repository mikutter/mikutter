require 'test/unit'
require File.dirname(__FILE__) + '/../utils'
miquire :core, 'message'

$debug = 2

class TC_Message < Test::Unit::TestCase
  def setup
  end

  def test_hierarchy
    toshi = User.new_ifnecessary(:id => 123456, :idname => 'toshi_a', :name => 'toshi')
    miku = User.new_ifnecessary(:id => 393939, :idname => 'ha2ne39', :name => 'miku')
    c5 = Message.new_ifnecessary(:id => 15, :message => 'inhibit ashamed words!', :user => miku, :replyto =>13, :created => Time.now)
    c4 = Message.new_ifnecessary(:id => 14, :message => '...baka///', :user => miku, :replyto =>13, :created => Time.now)
    c3 = Message.new_ifnecessary(:id => 13, :message => 'i happy. because u r cute!', :user => toshi, :replyto =>12, :created => Time.now) # !> already initialized constant HYDE
    c2 = Message.new_ifnecessary(:id => 12, :message => 'hi master, how r u?', :user => miku, :replyto =>11, :created => Time.now)
    c1 = Message.new_ifnecessary(:id => 11, :message => 'hey, miku!', :user => toshi, :created => Time.now)
    assert_instance_of Array, c2.children
    assert_equal c1.children[0], c2
    assert_equal c2.receive_message, c1
    assert_equal c2.children[0], c3 # !> method redefined; discarding old miquire
    assert_equal c3.receive_message, c2
    assert c3.children.include?(c4)
    assert c3.children.include?(c5)
    assert !c3.children.include?(c2)
    assert_equal c4.receive_message, c3
   end
end
# >> Loaded suite -
# >> Started
# >> .
# >> Finished in 0.002735 seconds.
# >> 
# >> 1 tests, 9 assertions, 0 failures, 0 errors
