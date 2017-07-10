# -*- coding: utf-8 -*-
#
# userlist.rb
#

# users list

require 'typed-array'

miquire :core, 'user', 'message'
miquire :lib, 'diva_hacks'

require 'set'

class UserList < Diva::Model
  extend Memoist

  include Diva::Model::Identity

  # args format
  # key         | value(class)
  #-------------+--------------
  # id          | id of status(mixed)
  # name        | name of list(String)
  # public      | access mode(boolean:public if true)
  # description | memo(String)
  # user        | user who post this message(User or Hash or mixed(User IDNumber))
  # slug        | list slug(String)

  field.int    :id, required: true
  field.string :name, required: true
  field.bool   :mode
  field.string :description
  field.has    :user, User, required: true
  field.string :slug, required: true
  field.has    :member, [User]

  def initialize(value)
    type_strict value => Hash
    super(value)
  end

  # リストを所有しているユーザを返す
  # ==== Return
  # リストの所有者(User)
  def user
    self[:user] end

  memoize def perma_link
    Diva::URI.new("https://twitter.com/#{user.idname}/lists/#{CGI.escape(slug)}") end

  def member
    self[:member] ||= Set.new end

  def member?(user)
    member.include?(user) if user.is_a? User end

  # リプライだった場合、投稿した人と宛先が一人でもリストメンバーだったら真。
  # リプライではない場合は、 UserList.member?(message.user) と同じ
  # ==== Args
  # [message] 調べるMessage
  # ==== Return
  # リスト内のMessageなら真
  def related?(message)
    idnames = message.receive_user_screen_names
    member?(message.user) && (idnames.empty? or member.any?{ |u| idnames.include?(u.idname) }) end

  def add_member(user)
    member_update_transaction do
      if user.is_a? User
        member << user
      elsif user.is_a? Integer
        Thread.new {
          user = User.findbyid(user)
          member << user }
      elsif user.is_a? Enumerable
        user.each(&method(:add_member))
      else
        raise ArgumentError.new('UserList member must be User') end end
    self end

  def remove_member(user)
    member_update_transaction do
      if user.is_a? User
        member.delete(user)
      elsif user.is_a? Integer
        member.delete(User.findbyid(user))
      elsif user.is_a? Enumerable
        user.map(&remove_member)
      else
        raise ArgumentError.new('UserList member must be User') end end
    self end

  private
  def member_update_transaction
    before = member.dup
    result = yield
    if before != member
      Plugin.call(:list_member_changed, self)
      self.class.store_datum(self) end
    result end

end

class UserLists < TypedArray(UserList)
end
