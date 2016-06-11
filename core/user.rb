# -*- coding: utf-8 -*-

miquire :core, 'retriever', 'skin'

miquire :lib, 'typed-array'

class User < Retriever::Model
  extend Gem::Deprecate

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
               [:verified, :bool],
               [:followers_count, :int],
               [:statuses_count, :int],
               [:friends_count, :int],
              ]

  def self.system
    if not defined? @@system then
      @@system = User.new({ :id => 0,
                            :idname => 'mikutter_bot',
                            :name => Environment::NAME,
                            :profile_image_url => Skin.get("icon.png")})
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

  def self.container_class
    Users end

  def initialize(*args)
    super
    @@users_id[idname] = self end

  def idname
    self[:idname] end
  alias to_s idname

  def protected?
    !!self[:protected]
  end

  def verified?
    !!self[:verified]
  end

  # 大きいサイズのアイコンのURLを返す
  # ==== Return
  # 元のサイズのアイコンのURL
  def profile_image_url_large
    url = self[:profile_image_url]
    if url
      url.gsub(/_normal(.[a-zA-Z0-9]+)\Z/, '\1') end end

  def follow
    if(@value[:post]) then
      @value[:post].follow(self)
    end
  end

  def inspect
    "User(@#{@value[:idname]})"
  end

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

  # このUserオブジェクトが、登録されているアカウントのうちいずれかのものであるなら true を返す
  def me?(service = Service.instances)
    if service.is_a? Enumerable
      service.any?(&method(:me?))
    elsif service.is_a? Service
      service.user_obj == self end end

  # 互換性のため
  alias is_me? me?
  deprecate :is_me?, "me?", 2017, 05

  # :nodoc:
  def count_favorite_by
    Thread.new {raise RuntimeError, 'Favstar is dead.'} end
  deprecate :count_favorite_by, :none, 2017, 05


  # ユーザが今までにお気に入りにしたメッセージ数の概算を返す
  def count_favorite_given
    @value[:favourites_count] end

  def user
    self end
  alias to_user user

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

class Users < TypedArray(User)
end
