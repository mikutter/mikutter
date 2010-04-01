class User
  @@users = Hash.new
  @@idname_id = Hash.new

  # args format
  # key     | value
  # --------+-----------
  # id      | user id
  # idname  | account name
  # nickname| account usual name
  # location| location(not required)
  # detail  | detail
  # profile_image_url | icon
  def initialize(*args)
    if(args[0].is_a?(Hash)) then
      @value = args[0]
    else
      @value = Hash[*args]
    end
    self.regist
  end

  def self.system
    if not defined? @@system then
      @@system = User.new({ :id => 0,
                            :idname => Environment::ACRO,
                            :name => Environment::NAME,
                            :profile_image_url => "core#{File::SEPARATOR}skin#{File::SEPARATOR}data#{File::SEPARATOR}icon.png"})
    end
    @@system
  end

  def self.generate(*args)
    return User.system if(args[0] == :system)
    if(args[0].is_a?(User)) then
      return args[0]
    elsif(args[0].is_a?(Hash)) then
      args = args[0]
    else
      args = Hash[*args]
    end
    if(@@users[args[:id]]) then
      return @@users[args[:id]].update(args)
    else
      return User.new(args)
    end
  end

  def update(other)
    @value.update(other.to_hash)
    return self
  end

  def follow
    if(@value[:post]) then
      @value[:post].follow(self)
    end
  end

  def to_hash
    @value.dup
  end

  def [](key)
    @value[key.to_sym]
  end

  def []=(key, val)
    @value[key.to_sym] = val
  end

  def regist
    @@users[self[:id]] = self
    @@idname_id[self[:idname]] = self[:id]
  end

  def inspect
    "User(@#{@value[:idname]})"
  end

  def self.findById(id)
    result = @@users[id]
    return result
  end

  def self.findByIdname(idname)
    id = @@idname_id[idname]
    self.findById(id) if(id)
  end

  def ==(other)
    if other.is_a?(String) then
      @value[:idname] == other
    elsif other.is_a?(User) then
      other[:id] == self[:id]
    end
  end

end
