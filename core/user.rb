# -*- coding: utf-8 -*-
require File.expand_path('utils')
miquire :core, 'retriever'
miquire :mui, 'skin'

class User < Retriever::Model

  @@users_id = WeakStorage.new(String, User) # {idname => User}

  # args format
  # key     | value
  # --------+-----------
  # id      | user id
  # idname  | account name
  # nickname| account usual name
  # location| location(not required)
  # detail  | detail
  # profile_image_url | icon

  self.keys = [[:id, :string],
               [:idname, :string],
               [:name, :string],
               [:location, :string],
               [:detail, :string],
               [:profile_image_url, :string],
               [:url, :string],
               [:protected, :bool],
               [:followers_count, :int],
               [:statuses_count, :int],
               [:friends_count, :int],
              ]

  def self.system
    if not defined? @@system then
      @@system = User.new({ :id => 0,
                            :idname => 'mikutter_bot',
                            :name => Environment::NAME,
                            :profile_image_url => MUI::Skin.get("icon.png")})
    end
    @@system
  end

  def self.memory_class
    result = Class.new do
      def self.set_users_id(users)
        @@users_id = users end

      def self.new(storage)
        UserMemory.new(storage, @@users_id) end end
    result.set_users_id(@@users_id)
    result end

  def initialize(*args)
    super
    @@users_id[idname] = self end

  def idname
    self[:idname] end
  alias to_s idname

  def follow
    if(@value[:post]) then
      @value[:post].follow(self)
    end
  end

  def inspect
    "User(@#{@value[:idname]})"
  end

  @@superof_new_ifnecessary = method(:new_ifnecessary)
  def self.new_ifnecessary(args)
    return args if args.is_a? User
    type_check(args => Hash){
      if args[:idname]
        result = self.findbyidname(args[:idname])
        return result if result end
      @@superof_new_ifnecessary.call(args) } end

  def self.findbyidname(idname, count=-1)
    if(@@users_id.has_key?(idname))
      @@users_id[idname]
    elsif caller(1).include?(caller[0])
      selectby(:idname, idname, count).first
    end
  end

  def self.store_datum(datum)
    return datum if datum[:id][0] == '+'[0]
    super
  end

  def ==(other)
    if other.is_a?(String) then
      @value[:idname] == other
    elsif other.is_a?(User) then
      other[:id] == self[:id] end end

  def is_me?(service = Service.all)
    if service.is_a? Enumerable
      service.any?(&method(:is_me?))
    elsif service.is_a? Service
      service.user_obj == self end end

  # ユーザのメッセージが今までお気に入りにされた回数を返す
  def count_favorite_by
    return @value[:favouritesby_count] if @value.has_key?(:favouritesby_count)
    begin
    open("http://favotter.net/user.php?user=#{idname}"){ |io|
      m = /のふぁぼられ\((\d+)\)/.match(io.read)
      return @value[:favouritesby_count] = m[1].to_i
    }
    rescue
      nil end end

  # ユーザが今までにお気に入りにしたメッセージ数の概算を返す
  def count_favorite_given
    return @value[:favourites_count] if @value.has_key?(:favourites_count)
    begin
      open("http://favotter.net/user/#{idname}&mode=fav"){ |io|
        m = /のふぁぼり\((\d+)\)/.match(io.read)
      return @value[:favourites_count] = m[1].to_i
    }
    rescue
      nil end end

  def marshal_dump
    raise RuntimeError, 'User cannot marshalize'
  end

  class UserMemory < Retriever::Model::Memory
    def initialize(storage, idnames)
      super(storage)
      @idnames = idnames
    end

    def selectby(key, value)
      if key == :idname and @idnames[value].is_a?(User)
        [@idnames[value]]
      else
        [] end end
  end

end
# ~> -:44: syntax error, unexpected kEND, expecting '}'
# ~> -:98: class definition in method body
# ~> -:115: syntax error, unexpected kEND, expecting '}'
