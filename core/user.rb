# -*- coding: utf-8 -*-

miquire :core, 'retriever', 'skin'
miquire :system, 'system'
miquire :lib, 'typed-array'

class User < Retriever::Model
  extend Gem::Deprecate
  extend Memoist
  include Retriever::Model::Identity
  include Retriever::Model::UserMixin

  register :twitter_user, name: "Twitter User"

  # args format
  # key     | value
  # --------+-----------
  # id      | user id
  # idname  | account name
  # nickname| account usual name
  # location| location(not required)
  # detail  | detail
  # profile_image_url | icon

  field.int    :id
  field.string :idname
  field.string :name
  field.string :location
  field.string :detail
  field.string :profile_image_url
  field.string :url
  field.bool   :protected
  field.bool   :verified
  field.int    :followers_count
  field.int    :statuses_count
  field.int    :friends_count

  handle %r[\Ahttps?://twitter.com/[a-zA-Z0-9_]+/?\Z] do |uri|
    match = %r[\Ahttps?://twitter.com/(?<screen_name>[a-zA-Z0-9_]+)/?\Z].match(uri.to_s)
    notice match.inspect
    if match
      user = findbyidname(match[:screen_name], Retriever::DataSource::USE_LOCAL_ONLY)
      if user
        user
      else
        Thread.new do
          findbyidname(match[:screen_name], Retriever::DataSource::USE_ALL)
        end
      end
    else
      raise Retriever::RetrieverError, "id##{match[:screen_name]} does not exist in #{self}."
    end
  end

  def self.system
    Mikutter::System::User.system end

  def self.memory
    @memory ||= UserMemory.new end

  def self.container_class
    Users end

  alias :to_i :id
  deprecate :to_i, "id", 2017, 05

  def idname
    self[:idname] end
  alias to_s idname

  def title
    "#{idname}(#{name})"
  end

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
    false end

  def self.findbyidname(idname, count=Retriever::DataSource::USE_ALL)
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
    Retriever::URI.new("https://twitter.com/#{idname}")
  end

  alias to_user user

  def marshal_dump
    raise RuntimeError, 'User cannot marshalize'
  end

  class UserMemory < Retriever::Model::Memory
    def initialize
      super
      @idnames = {}             # idname => User
    end

    def findbyid(id, policy)
      result = super
      if !result and policy == Retriever::DataSource::USE_ALL
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
      elsif policy == Retriever::DataSource::USE_ALL
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
