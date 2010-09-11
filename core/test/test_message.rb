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
    c2 = Message.new_ifnecessary(:id => 12, :message => 'hi master, how r u?', :user => miku, :replyto =>11, :created => Time.now) # !> method redefined; discarding old inspect
    c1 = Message.new_ifnecessary(:id => 11, :message => 'hey, miku!', :user => toshi, :created => Time.now)
    assert_instance_of Array, c2.children
    assert_equal c1.children[0], c2
    assert_equal c2.receive_message, c1
    assert_equal c2.children[0], c3
    assert_equal c3.receive_message, c2
    assert c3.children.include?(c4)
    assert c3.children.include?(c5)
    assert !c3.children.include?(c2)
    assert_equal c4.receive_message, c3
   end
end
# ~> notice: ./post.rb:58:in `initialize': -:13:in `new'
# ~> ./retriever.rb:342: warning: instance variable @time not initialized
# ~> ./retriever.rb:342: warning: instance variable @time not initialized
# ~> notice: ./post.rb:58:in `initialize': -:13:in `new'
# ~> notice: ./twitter_api.rb:174:in `get': /statuses/show/24006538707.json => #<Net::HTTPOK:0x7fd626d42430>
# ~> ./retriever.rb:342: warning: instance variable @time not initialized
# ~> notice: ./twitter_api.rb:203:in `query_with_auth': get /account/verify_credentials.json => #<Net::HTTPOK:0x7fd626d13770>
# ~> notice: ./twitter_api.rb:174:in `get': /statuses/show/24005765187.json => #<Net::HTTPOK:0x7fd626cf5dd8>
# ~> ./retriever.rb:342: warning: instance variable @time not initialized
# >> Loaded suite -
# >> Started
# >> .#<Message:0x7fd626d266e0 @value={:geo=>nil, :contributors=>nil, :exact=>true, :source=>"<a href="http://mikutter.d.hachune.net/" rel="nofollow">mikutter</a>", :retweet_count=>nil, :place=>nil, :message=>"@t_min 設定ファイル書き換えロジックは、ちょっとばっかりそれらしい書き方してるからなー。初学者向けではない。", :retweeted=>false, :user=>User(@kaorin_linux), :coordinates=>nil, :rule=>:status_show, :image=>#<Message::Image:0x7fd626d26690 @url=nil, @resource=nil>, :in_reply_to_screen_name=>"t_min", :receiver=>33031948, :replyto=>24005765187, :truncated=>false, :created=>木  9月 09 21:54:54 +0900 2010, :id=>24006538707, :favorited=>false, :created_at=>"Thu Sep 09 12:54:54 +0000 2010", :post=>#<Post toshi_a>}, @lock=#<Monitor:0x7fd626d26618 @mon_entering_queue=[], @mon_count=0, @mon_owner=nil, @mon_waiting_queue=[]>>
# >> 急に理解した。けど設定ファイルの書き換えがわけわかめ。つかこれ、全部自分で書けって言われたらキツイな。追加とか書き換えとか置き換えはできそうだけど。
# >> .
# >> Finished in 1.022638 seconds.
# >> 
# >> 2 tests, 9 assertions, 0 failures, 0 errors
