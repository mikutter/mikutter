require 'test/unit'
require File.dirname(__FILE__) + '/../utils'
miquire :core, 'message'
miquire :core, 'post'

$debug = true
seterrorlevel(:notice)
$logfile = nil
$daemon = false

class TC_Message < Test::Unit::TestCase
  def setup
  end # !> `*' interpreted as argument prefix

  def test_retrieve
    id = 23858662507
    puts Message.findbyid(id).inspect # !> already initialized constant HYDE
    puts Message.new_ifnecessary(:id => id).inspect
  end

  def test_hierarchy
    toshi = User.new_ifnecessary(:id => 123456, :idname => 'toshi_a', :name => 'toshi')
    miku = User.new_ifnecessary(:id => 393939, :idname => 'ha2ne39', :name => 'miku') # !> method redefined; discarding old miquire
    c5 = Message.new_ifnecessary(:id => 15, :message => 'inhibit ashamed words!', :user => miku, :replyto =>13, :created => Time.now)
    c4 = Message.new_ifnecessary(:id => 14, :message => '...baka///', :user => miku, :replyto =>13, :created => Time.now)
    c3 = Message.new_ifnecessary(:id => 13, :message => 'i happy. because u r cute!', :user => toshi, :replyto =>12, :created => Time.now)
    c2 = Message.new_ifnecessary(:id => 12, :message => 'hi master, how r u?', :user => miku, :replyto =>11, :created => Time.now)
    c1 = Message.new_ifnecessary(:id => 11, :message => 'hey, miku!', :user => toshi, :created => Time.now)
    assert_instance_of Array, c2.children
    assert_equal c1.children[0], c2
    assert_equal c2.receive_message, c1 # !> method redefined; discarding old inspect
    assert_equal c2.children[0], c3
    assert_equal c3.receive_message, c2
    assert c3.children.include?(c4)
    assert c3.children.include?(c5)
    assert !c3.children.include?(c2)
    assert_equal c4.receive_message, c3
   end
end
# >> Loaded suite -
# >> Started
# >> .#<Message:0x7f76f0cc1f50 @lock=#<Monitor:0x7f76f0cc1e88 @mon_owner=nil, @mon_waiting_queue=[], @mon_entering_queue=[], @mon_count=0>, @value={:image=>#<Message::Image:0x7f76f0cc1f00 @url=nil, @resource=nil>, :source=>"<a href="http://mikutter.d.hachune.net/" rel="nofollow">mikutter</a>", :message=>"でも、これCの人のクセなんかね。結構ifバーッと並べていくCerって確かに多いんだよ。逐次処理頼りにしてるのか。実は結構if〜elseとか書かないよな。ネットで散見してるの読む限り。", :user=>"82571791", :retweet=>nil, :replyto=>nil, :receiver=>nil, :geo=>nil, :created=>水  9月 08 07:37:30 +0900 2010, :exact=>nil, :id=>23858662507}>
# >> #<Message:0x7f76f0cc1f50 @lock=#<Monitor:0x7f76f0cc1e88 @mon_owner=nil, @mon_waiting_queue=[], @mon_entering_queue=[], @mon_count=0>, @value={:image=>#<Message::Image:0x7f76f0cc1f00 @url=nil, @resource=nil>, :source=>"<a href="http://mikutter.d.hachune.net/" rel="nofollow">mikutter</a>", :message=>"でも、これCの人のクセなんかね。結構ifバーッと並べていくCerって確かに多いんだよ。逐次処理頼りにしてるのか。実は結構if〜elseとか書かないよな。ネットで散見してるの読む限り。", :user=>"82571791", :retweet=>nil, :replyto=>nil, :receiver=>nil, :geo=>nil, :created=>水  9月 08 07:37:30 +0900 2010, :exact=>nil, :id=>23858662507}>
# >> .
# >> Finished in 0.009562 seconds.
# >> 
# >> 2 tests, 9 assertions, 0 failures, 0 errors
