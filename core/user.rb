# -*- coding: utf-8 -*-

miquire :core, 'retriever', 'skin'

miquire :lib, 'typed-array'

class User < Retriever::Model
  extend Gem::Deprecate
  include Retriever::Model::Identity

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

  def memory
    @memory ||= UserMemory.new end

  def self.container_class
    Users end

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

  # 投稿がシステムユーザだった場合にtrueを返す
  def system?
    self[:system] end

  def self.findbyidname(idname, count=Retriever::DataSource::ALL)
    memory.findbyidname(idname, count) end

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

  memoize def perma_link
    URI.parse("https://twitter.com/#{idname}").freeze end

  def user
    self end
  alias to_user user

  def marshal_dump
    raise RuntimeError, 'User cannot marshalize'
  end

  class UserMemory < Retriever::Model::Memory
    def initialize(storage)
      super(storage)
      @idnames = {}             # idname => User
    end

    def findbyid(id, policy)
      result = super
      if !result and policy == Retriever::DataSource::ALL
        if id.is_a? Enumerable
          id.each_slice(100).map{|id_list|
            Service.primary.scan(:user_lookup, id: id_list.join(','.freeze)) || [] }.flatten
        else
          Service.primary.scan(:user_show, id: id) end
      else
        result end end

    def findbyidname(idname, policy)
      if @idnames[idname.to_s]
        @idnames[idname.to_s]
      elsif policy == Retriever::DataSource::ALL
        Service.primary.scan(:user_show, screen_name: idname)
      end
    end

    def store_datum(retriever)
      @idnames[retriever.idname.to_s] = retriever
      super
    end
  end

end

class Users < TypedArray(User)
end
