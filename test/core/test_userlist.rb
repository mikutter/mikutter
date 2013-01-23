# -*- coding: utf-8 -*-
require 'test/unit'
require 'mocha'
require File.expand_path(File.join(File.dirname(__FILE__), '../../core/utils'))
miquire :lib, 'test_unit_extensions'
miquire :core, 'userlist'
miquire :core, 'service'

Dir::chdir File.dirname(__FILE__) + '/../'

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
    user_obj = {
      id: 164348251,
      name: "mikutter_bot",
      idname: "mikutter_bot" }
    user = User.new_ifnecessary( user_obj )
    Service.any_instance.stubs(:user_initialize).returns(user)
    @service ||= Service.new
  end # !> ambiguous first argument; put parentheses or even spaces

  must "get member" do
    u = [User.new_ifnecessary(:id => 128450, :idname => 'a', :name => 'a'),
         User.new_ifnecessary(:id => 128451, :idname => 'b', :name => 'b'),
         User.new_ifnecessary(:id => 128452, :idname => 'c', :name => 'c')]
    l = [UserList.new_ifnecessary(id: 128453, name: "testlist", full_name: "@a/testlist", slug: "@a/testlist", user: u[0], member: [ u[1] ]),
         UserList.new_ifnecessary(id: 128454, name: "testlist2", full_name: "@a/testlist2", slug: "@a/testlist", user: u[0], member: [ u[1], u[2] ])]
    assert_equal [u[1]], l[0].member
    assert_equal [u[1], u[2]], l[1].member
  end

  must "member?" do
    u = [User.new_ifnecessary(:id => 128450, :idname => 'a', :name => 'a'),
         User.new_ifnecessary(:id => 128451, :idname => 'b', :name => 'b'),
         User.new_ifnecessary(:id => 128452, :idname => 'c', :name => 'c')]
    l = [UserList.new_ifnecessary(id: 128453, name: "testlist", full_name: "@a/testlist", slug: "@a/testlist", user: u[0], member: [ u[1] ]),
         UserList.new_ifnecessary(id: 128454, name: "testlist2", full_name: "@a/testlist2", slug: "@a/testlist", user: u[0], member: [ u[1], u[2] ])]
    assert not(l[0].member? u[0])
    assert l[0].member? u[1]
    assert not(l[0].member? u[2])
    assert not(l[1].member? u[0])
    assert l[1].member? u[1]
    assert l[1].member? u[2]
  end

  must "related" do
    u = [User.new_ifnecessary(:id => 128450, :idname => 'a', :name => 'a'),
         User.new_ifnecessary(:id => 128451, :idname => 'b', :name => 'b'),
         User.new_ifnecessary(:id => 128452, :idname => 'c', :name => 'c')]
    l = [UserList.new_ifnecessary(id: 128453, name: "testlist", full_name: "@a/testlist", slug: "@a/testlist", user: u[0], member: [ u[1] ]),
         UserList.new_ifnecessary(id: 128454, name: "testlist2", full_name: "@a/testlist2", slug: "@a/testlist", user: u[0], member: [ u[1], u[2] ])]
    m = [[Message.new_ifnecessary(id: 639620, message: "", user: u[0]),
          Message.new_ifnecessary(id: 639621, message: "", user: u[1]),
          Message.new_ifnecessary(id: 639622, message: "", user: u[2])],
         [Message.new_ifnecessary(id: 639600, message: "@b", user: u[0]),
          Message.new_ifnecessary(id: 639601, message: "@b", user: u[1]),
          Message.new_ifnecessary(id: 639602, message: "@b", user: u[2])],
         [Message.new_ifnecessary(id: 639610, message: "@b @c", user: u[0]),
          Message.new_ifnecessary(id: 639611, message: "@b @c", user: u[1]),
          Message.new_ifnecessary(id: 639612, message: "@b @c", user: u[2])]]
    assert !l[0].related?(m[0][0]), "リストに関係ないユーザa"
    assert l[0].related?(m[0][1])
    assert !l[0].related?(m[0][2])
    assert !l[1].related?(m[0][0])
    assert l[1].related?(m[0][1])
    assert l[1].related?(m[0][2])

    assert !l[0].related?(m[1][0]), "関係ないユーザaからリスト内ユーザbに対するリプライ"
    assert l[0].related?(m[1][1]), "リスト内ユーザbがリスト内ユーザbにリプライ"
    assert !l[0].related?(m[1][2]), "リスト内ユーザbが第三者cにリプライ"
    assert !l[1].related?(m[1][0])
    assert l[1].related?(m[1][1])
    assert l[1].related?(m[1][2])

    assert !l[0].related?(m[2][0])
    assert l[0].related?(m[2][1])
    assert !l[0].related?(m[2][2])
    assert !l[1].related?(m[2][0])
    assert l[1].related?(m[2][1])
    assert l[1].related?(m[2][2])
  end

end
