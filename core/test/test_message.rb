require 'test/unit'
require File.dirname(__FILE__) + '/../utils'
miquire :core, 'message'
miquire :core, 'post'

$debug = true
seterrorlevel(:notice)
$logfile = nil
$daemon = false

class TC_Message < Test::Unit::TestCase
  def setup # !> `*' interpreted as argument prefix
    @service ||= Post.new
  end

  def test_retrieve # !> already initialized constant HYDE
    id = 24006538707
    x = Message.findbyid(id)
    puts x.inspect
    puts x.receive_message(true)
    #puts Message.new_ifnecessary(:id => id).inspect
  end # !> method redefined; discarding old miquire

  def test_hierarchy
    toshi = User.new_ifnecessary(:id => 123456, :idname => 'toshi_a', :name => 'toshi')
    miku = User.new_ifnecessary(:id => 393939, :idname => 'ha2ne39', :name => 'miku')
    c5 = Message.new_ifnecessary(:id => 15, :message => 'inhibit ashamed words!', :user => miku, :replyto =>13, :created => Time.now)
    c4 = Message.new_ifnecessary(:id => 14, :message => '...baka///', :user => miku, :replyto =>13, :created => Time.now)
    c3 = Message.new_ifnecessary(:id => 13, :message => 'i happy. because u r cute!', :user => toshi, :replyto =>12, :created => Time.now)
    c1 = Message.new_ifnecessary(:id => 11, :message => 'hey, miku!', :user => toshi, :created => Time.now) # !> method redefined; discarding old inspect
    c2 = Message.new_ifnecessary(:id => 12, :message => 'hi master, how r u?', :user => miku, :replyto =>11, :created => Time.now)
    assert_equal(c1, c2.receive_message)
    assert_kind_of(Message, c2.receive_message)
    assert_kind_of(Message, c1)
    assert_equal(true, c1.children.include?(c2))
    assert_kind_of(Set, c2.children)
    assert_equal("#<Set: {}>", c2.children.inspect)
    assert_kind_of(Set, c3.children)
    assert_equal("#<Set: {}>", c3.children.inspect)
    assert_kind_of(Set, c4.children)
    assert_equal("#<Set: {}>", c4.children.inspect)
    assert_kind_of(Set, c5.children)
    assert_equal("#<Set: {}>", c5.children.inspect)

    # assert_instance_of Set, c2.children
    # assert_equal c2.receive_message, c1
    # assert_equal c3.receive_message, c2
    # assert c3.children.include?(c4)
    # assert c3.children.include?(c5)
    # assert !c3.children.include?(c2)
    # assert_equal c4.receive_message, c3
   end
end # !> method redefined; discarding old biif
# ~> notice: ./post.rb:58:in `initialize': -:13:in `new'
# ~> ./retriever.rb:328: warning: instance variable @time not initialized
# ~> ./retriever.rb:328: warning: instance variable @time not initialized
# ~> ./retriever.rb:328: warning: instance variable @time not initialized
# ~> ./retriever.rb:328: warning: instance variable @time not initialized
# ~> ./retriever.rb:328: warning: instance variable @time not initialized
# ~> ./retriever.rb:328: warning: instance variable @time not initialized
# ~> ./retriever.rb:328: warning: instance variable @time not initialized
# ~> ./retriever.rb:328: warning: instance variable @time not initialized
# ~> ./retriever.rb:328: warning: instance variable @time not initialized
# ~> ./retriever.rb:328: warning: instance variable @time not initialized
# ~> notice: ./post.rb:58:in `initialize': -:13:in `new'
# >> Loaded suite -
# >> Started
# >> .#<Message:0x7fde6355f7f0 @value={:geo=>nil, :exact=>nil, :source=>"<a href="http://mikutter.d.hachune.net/" rel="nofollow">mikutter</a>", :message=>"@t_min 設定ファイル書き換えロジックは、ちょっとばっかりそれらしい書き方してるからなー。初学者向けではない。", :user=>"98686215", :receiver=>"33031948", :replyto=>"24005765187", :created=>木  9月 09 21:54:54 +0900 2010, :retweet=>nil, :id=>24006538707}>
# >> 急に理解した。けど設定ファイルの書き換えがわけわかめ。つかこれ、全部自分で書けって言われたらキツイな。追加とか書き換えとか置き換えはできそうだけど。
# >> .
# >> Finished in 0.013805 seconds.
# >> 
# >> 2 tests, 12 assertions, 0 failures, 0 errors
