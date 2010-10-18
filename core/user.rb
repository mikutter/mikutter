require File.expand_path('utils')
miquire :core, 'retriever'

class User < Retriever::Model

  @@users_id = WeakStorage.new # {idname => User}

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
                            :idname => Environment::ACRO,
                            :name => Environment::NAME,
                            :profile_image_url => MUI::Skin.get("icon.png")})
    end
    @@system
  end

  def initialize(*args)
    super
    @@users_id[idname] = self end

  def idname
    self[:idname]
  end

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
    type_check(args => Hash){
      if args[:idname]
        result = self.findbyidname(args[:idname])
        return result if result end
      @@superof_new_ifnecessary.call(args) } end

  def self.findbyidname(idname, count=-1)
    if(@@users_id.has_key?(idname))
      @@users_id[idname]
    elsif caller(1).include?(caller[0].first)
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
      other[:id] == self[:id]
    end
  end

  def marshal_dump
    raise RuntimeError, 'User cannot marshalize'
  end

  class Memory
    @@idnames = Hash.new
    def selectby(key, value)
      if key == :idname and @@idnames[value]
        [findbyid(@@idnames[value])]
      else
        [] end end

    def store_datum(datum)
      @@idnames[datum[:idname]] = datum[:id]
      super end end

end
