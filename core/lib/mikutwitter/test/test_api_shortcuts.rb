# -*- coding: utf-8 -*-
require "#{File.dirname(__FILE__)}/extension"

require 'test/unit'
require 'mocha'
require 'webmock/test_unit'
require 'pp'
require 'utils'
miquire :lib, 'delayer', 'test_unit_extensions', 'mikutwitter'
miquire :core, 'message', 'user', 'userlist'

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
    stub_request(:get, "#{@m.base_path}/statuses/user_timeline.json?user_id=15926668").
      to_return(:status => 200, :body => file_get_contents(File.join(MIKUTWITTER_TEST_DIR, 'user_timeline.json')), :headers => {})
    @m.user_timeline(:user_id => 15926668).next{ |res|
      result = res
    }
    wait_all_tasks
    assert_equal 279875210533019648, result[0][:id]
    assert_equal 279870667065794560, result[1][:id]
  end

  must "home_timeline" do
    result = nil
    stub_request(:get, "#{@m.base_path}/statuses/home_timeline.json").
      to_return(:status => 200, :body => file_get_contents(File.join(MIKUTWITTER_TEST_DIR, 'user_timeline.json')), :headers => {})
    @m.home_timeline.next{ |res|
      result = res
    }
    wait_all_tasks
    assert_equal 279875210533019648, result[0][:id]
    assert_equal 279870667065794560, result[1][:id]
  end

  must "status_show" do
    result = nil
    stub_request(:get, "#{@m.base_path}/statuses/show.json?id=159562753319768064").
      to_return(:status => 200, :body => file_get_contents(File.join(MIKUTWITTER_TEST_DIR, 'status_show.json')), :headers => {})
    @m.status_show(id: 159562753319768064).next{ |res|
      result = res
    }.trap{ |err| p err; pp err.backtrace }
    wait_all_tasks
    assert_equal 159562753319768064, result[:id]
  end

  must "search" do
    result = nil
    stub_request(:get, "#{@m.base_path}/search/tweets.json?q=%23mikutter").
      to_return(:status => 200, :body => file_get_contents(File.join(MIKUTWITTER_TEST_DIR, 'search.json')), :headers => {})
    @m.search(q: '#mikutter').next{ |res|
      result = res
    }.trap{ |err| p err; pp err.backtrace }
    wait_all_tasks
    assert_equal 279890274044489728, result[0][:id]
    assert_equal 91704555, result[0].user[:id]
  end

  must "friendship" do
    result = nil
    stub_request(:get, "#{@m.base_path}/friendships/show.json?source_id=15926668&target_id=164348251").
      to_return(:status => 200, :body => file_get_contents(File.join(MIKUTWITTER_TEST_DIR, 'friendship.json')), :headers => {})
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
    stub_request(:get, "#{@m.base_path}/users/show.json?user_id=15926668").
      to_return(:status => 200, :body => file_get_contents(File.join(MIKUTWITTER_TEST_DIR, 'user.json')), :headers => {})
    @m.user_show(user_id: 15926668).next{ |res|
      result = res
    }.trap{ |err| p err; pp err.backtrace }
    wait_all_tasks
    assert_equal 15926668, result[:id]
  end

  must "lists" do
    result = nil
    stub_request(:get, "#{@m.base_path}/lists/list.json?user_id=15926668").
      to_return(:status => 200, :body => file_get_contents(File.join(MIKUTWITTER_TEST_DIR, 'lists_all.json')), :headers => {})
    @m.lists(user_id: 15926668).next{ |res|
      result = res
    }.trap{ |err| p err; pp err.backtrace }
    wait_all_tasks
    assert_equal(23, result.count) # !> ambiguous first argument; put parentheses or even spaces
    assert_equal(59738573, result[0][:user][:id])
    assert_equal(914077, result[0][:id])
    assert_equal("netbsd-japanese", result[0][:slug])
  end

  must "list user followers" do
    result = nil
    stub_request(:get, "#{@m.base_path}/lists/memberships.json?user_id=80739771").
      to_return(:status => 200, :body => file_get_contents(File.join(MIKUTWITTER_TEST_DIR, 'list_memberships.json')))
    @m.list_user_followers(user_id: 80739771).next{ |res|
      result = res
    }.trap{ |err| p err; pp err.backtrace }
    wait_all_tasks
    assert_equal ["teokure", "〄て〄お〄く〄れ〄", "Tech", "teokure", "toshi_a", "toshi_a_icon_club", "toshi", "a", "ComputerHumanoidInterface"], result.map{ |l| l[:name] }
  end

  must "list_subscriptions" do
    result = nil
    stub_request(:get, "#{@m.base_path}/lists/subscriptions.json?count=1000&user_id=15926668").
      to_return(:status => 200, :body => file_get_contents(File.join(MIKUTWITTER_TEST_DIR, 'list_subscriptions.json')), :headers => {})
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
    stub_request(:get, "#{@m.base_path}/lists/members.json?id=55073842&list_id=55073842").
      to_return(:status => 200, :body => file_get_contents(File.join(MIKUTWITTER_TEST_DIR, 'list_member.json')), :headers => {})

    stub_request(:get, "#{@m.base_path}/lists/members.json?cursor=1380555797979069262&id=55073842&list_id=55073842").
      to_return(:status => 200, :body => file_get_contents(File.join(MIKUTWITTER_TEST_DIR, 'list_member_1380555797979069262.json')), :headers => {})

    stub_request(:get, "#{@m.base_path}/lists/members.json?cursor=1380555359495881433&id=55073842&list_id=55073842").
      to_return(:status => 200, :body => file_get_contents(File.join(MIKUTWITTER_TEST_DIR, 'list_member_1380555359495881433.json')), :headers => {})

    @m.list_members(id: 55073842).next{ |res|
      result = res
    }.trap{ |err| p err; pp err.backtrace }
    wait_all_tasks
    assert_instance_of Array, result
    expected = Set.new([134431872, 69505027, 114994247, 5161091, 14889894, 6257722, 14299185, 146056548, 252004214, 227687955, 14864316, 103841612, 19049499, 91345106, 134185304, 15926668, 163062925, 16331137, 165318039, 120019687, 227349581, 82888635, 80739771, 99320137, 52049454, 81564754, 84863232, 90394630, 242296876, 294635954, 99262813, 353583238, 82103990, 100811022, 358852188, 66159300, 363044279, 96564598, 84843705, 14157458, 369015960, 83307042, 14656104, 112705330, 309133958, 271931846, 41118154, 328464796, 369097215, 374288046, 268897524, 315872815, 318855175, 16668263, 376964790, 334723728])
    assert_equal expected, Set.new(result.map{ |u| u[:id] })
  end

  must "update" do
    result = nil
    stub_request(:post, "#{@m.base_path}/statuses/update.json").
      with(:body => {"status"=>"みくちゃんﾅｰ"}).
      to_return(:status => 200, :body => file_get_contents(File.join(MIKUTWITTER_TEST_DIR, 'status_update_success.json')), :headers => {})
    @m.update(message: "みくちゃんﾅｰ").next{ |res|
      result = res
    }.trap{ |err| p err; pp err.backtrace }
    wait_all_tasks
    assert_equal 160577149751918592, result[:id]
    assert_equal 15926668, result[:user][:id]
    assert_equal "みくちゃんﾅｰ", result.body
  end

end
