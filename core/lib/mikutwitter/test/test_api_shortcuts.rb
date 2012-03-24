# -*- coding: utf-8 -*-

DIR = File.expand_path(File.dirname($0))
$LOAD_PATH.push(File.expand_path(File.join(File.dirname($0), '../../..')))

require 'test/unit'
require 'mocha'
require 'webmock/test_unit'
require 'pp'
require 'utils'
miquire :lib, 'test_unit_extensions', 'mikutwitter'
miquire :core, 'delayer', 'message', 'user', 'userlist'

class Plugin
  def self.call(*args); end end

class TC_mikutwitter_api_call_support < Test::Unit::TestCase

  def setup
    wait_all_tasks
    MikuTwitter::ApiCallSupport::Request::Parser.stubs(:message_appear).returns(stub_everything)
    @m = MikuTwitter.new
    @m.consumer_key = Environment::TWITTER_CONSUMER_KEY
    @m.consumer_secret = Environment::TWITTER_CONSUMER_SECRET
    @m.a_token = UserConfig[:twitter_token]
    @m.a_secret = UserConfig[:twitter_secret]
  end

  def wait_all_tasks
    while !Delayer.empty? or !(Thread.list - [Thread.current]).empty?
      Delayer.run
      (Thread.list - [Thread.current]).each &:join end
    assert_equal true, Delayer.empty?
    assert_equal [], (Thread.list - [Thread.current])
  end

  must "user_timeline" do
    result = nil
    stub_request(:get, "http://api.twitter.com/1/statuses/user_timeline.json?include_entities=1&user_id=15926668").
      with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent'=>'Ruby'}).
      to_return(:status => 200, :body => file_get_contents(File.join(DIR, 'user_timeline.json')), :headers => {})
    @m.user_timeline(:user_id => 15926668).next{ |res|
      result = res
    }
    wait_all_tasks
    assert_equal 159774132920262657, result[0][:id]
    assert_equal 159703433794957313, result[1][:id]
  end

  must "home_timeline" do
    result = nil
    stub_request(:get, "http://api.twitter.com/1/statuses/home_timeline.json?include_entities=1").
      to_return(:status => 200, :body => file_get_contents(File.join(DIR, 'user_timeline.json')), :headers => {})
    @m.home_timeline.next{ |res|
      result = res
    }.trap{ |err| p err }
    wait_all_tasks
    assert_equal 159774132920262657, result[0][:id]
    assert_equal 159703433794957313, result[1][:id]
  end

  must "status_show" do
    result = nil
    stub_request(:get, "http://api.twitter.com/1/statuses/show.json?id=159562753319768064&include_entities=1").
      to_return(:status => 200, :body => file_get_contents(File.join(DIR, 'status_show.json')), :headers => {})
    @m.status_show(id: 159562753319768064).next{ |res|
      result = res
    }.trap{ |err| p err; pp err.backtrace }
    wait_all_tasks
    assert_equal 159562753319768064, result[:id]
  end

  must "search" do
    result = nil
    stub_request(:get, "http://search.twitter.com/search.json?host=search.twitter.com&q=%23mikutter").
      with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent'=>'Ruby'}).
      to_return(:status => 200, :body => file_get_contents(File.join(DIR, 'search.json')), :headers => {})
    @m.search(q: '#mikutter').next{ |res|
      result = res
    }.trap{ |err| p err; pp err.backtrace }
    wait_all_tasks
    assert_equal 159814234316877825, result[0][:id]
    assert_equal 209909156, result[0].user[:id]
  end

  must "friendship" do
    result = nil
    stub_request(:get, "http://api.twitter.com/1/friendships/show.json?source_id=15926668&target_id=164348251").
      to_return(:status => 200, :body => file_get_contents(File.join(DIR, 'friendship.json')), :headers => {})
    @m.friendship(source_id: 15926668, target_id: 164348251).next{ |res|
      result = res
    }.trap{ |err| p err; pp err.backtrace }
    wait_all_tasks
    assert_equal true, result[:following]
    assert_equal true, result[:followed_by]
    assert_equal 164348251, result[:user][:id]
  end

  must "user_show" do
    result = nil
    stub_request(:get, "http://api.twitter.com/1/users/show.json?user_id=15926668").
      with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent'=>'Ruby'}).
      to_return(:status => 200, :body => file_get_contents(File.join(DIR, 'user.json')), :headers => {})
    @m.user_show(user_id: 15926668).next{ |res|
      result = res
    }.trap{ |err| p err; pp err.backtrace }
    wait_all_tasks
    assert_equal 15926668, result[:id]
  end

  must "lists" do
    result = nil
    stub_request(:get, "http://api.twitter.com/1/lists/all.json?user_id=15926668").
      to_return(:status => 200, :body => file_get_contents(File.join(DIR, 'lists_all.json')), :headers => {})
    @m.lists(user_id: 15926668).next{ |res|
      result = res
    }.trap{ |err| p err; pp err.backtrace }
    wait_all_tasks
    assert_equal(22, result.count) # !> ambiguous first argument; put parentheses or even spaces
    assert_equal(59738573, result[0][:user][:id])
    assert_equal(914077, result[0][:id])
    assert_equal("netbsd-japanese", result[0][:slug])
  end

  must "list user followers" do
    result = nil
    stub_request(:get, "http://api.twitter.com/1/lists/memberships.json?user_id=80739771").
      to_return(file_get_contents(File.join(DIR, 'list_memberships.json')))
    @m.list_user_followers(user_id: 80739771).next{ |res|
      result = res
    }.trap{ |err| p err; pp err.backtrace }
    wait_all_tasks
    assert_equal ["Tech", "IT・Web", "teokure", "toshi_a", "toshi_a_icon_club", "toshi", "a", "ComputerHumanoidInterface"], result.map{ |l| l[:name] }
  end

  must "list_subscriptions" do
    result = nil
    stub_request(:get, "http://api.twitter.com/1/lists/subscriptions.json?count=1000&user_id=15926668").
      to_return(:status => 200, :body => file_get_contents(File.join(DIR, 'list_subscriptions.json')), :headers => {})
    @m.list_subscriptions(user_id: 15926668).next{ |res|
      result = res
    }.trap{ |err| p err; pp err.backtrace }
    wait_all_tasks
    assert_equal(6, result.count) # !> ambiguous first argument; put parentheses or even spaces
    assert_equal(59738573, result[0][:user][:id])
    assert_equal(914077, result[0][:id])
    assert_equal("netbsd-japanese", result[0][:slug])
  end

  must "list_member" do
    result = nil
    stub_request(:get, "http://api.twitter.com/1/lists/members.json?id=55073842&list_id=55073842").
      to_return(:status => 200, :body => file_get_contents(File.join(DIR, 'list_member.json')), :headers => {})

    stub_request(:get, "http://api.twitter.com/1/lists/members.json?cursor=1380555359495881433&id=55073842&list_id=55073842").
      to_return(:status => 200, :body => file_get_contents(File.join(DIR, 'list_member_1380555359495881433.json')), :headers => {})

    stub_request(:get, "http://api.twitter.com/1/lists/members.json?cursor=1380555797979069262&id=55073842&list_id=55073842").
      to_return(:status => 200, :body => file_get_contents(File.join(DIR, 'list_member_1380555797979069262.json')), :headers => {})

    @m.list_members(id: 55073842).next{ |res|
      result = res
    }.trap{ |err| p err; pp err.backtrace }
    wait_all_tasks
    assert_instance_of Array, result
    assert_equal Set.new([134431872, 69505027, 114994247, 5161091, 6257722, 14299185, 146056548, 252004214, 227687955, 14864316, 103841612, 19049499, 91345106, 134185304, 15926668, 163062925, 86049415, 16331137, 165318039, 120019687, 227349581, 82888635, 80739771, 99320137, 52049454, 81564754, 84863232, 90394630, 242296876, 294635954, 99262813, 353583238, 82103990, 100811022, 358852188, 66159300, 363044279, 96564598, 84843705, 14157458, 369015960, 83307042, 14656104, 112705330, 309133958, 271931846, 41118154, 328464796, 369097215, 374288046, 268897524, 315872815, 318855175, 16668263, 376964790, 334723728]),
    Set.new(result.map{ |u| u[:id] })
  end

  must "update" do
    result = nil
    stub_request(:post, "http://api.twitter.com/1/statuses/update.json").
      with(:body => {"include_entities"=>"1", "status"=>"みくちゃんﾅｰ"}).
      to_return(:status => 200, :body => file_get_contents(File.join(DIR, 'status_update_success.json')), :headers => {})
    @m.update(message: "みくちゃんﾅｰ").next{ |res|
      result = res
    }.trap{ |err| p err; pp err.backtrace }
    wait_all_tasks
    assert_equal 160577149751918592, result[:id]
    assert_equal 15926668, result[:user][:id]
    assert_equal "みくちゃんﾅｰ", result.body
  end

end
