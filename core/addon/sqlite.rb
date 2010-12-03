# -*- coding: utf-8 -*-
#
# Mikutter SQLite
#

# 以下のコマンドで、sqliteをインストールして下さい
# sudo aptitude install libsqlite3-dev ruby-dev
# gem install sqlite3-ruby

require File.expand_path('utils')
miquire :addon, 'settings'
miquire :core, 'config'
miquire :core, 'user'
miquire :core, 'message'
miquire :core, 'userlist'
miquire :core, 'retriever'

require_if_exist 'sqlite3'

if defined? SQLite3

  Module.new do
    plugin = Plugin.create(:sqlite)
    db = SQLite3::Database.new(File::expand_path(Config::CONFROOT + "sqlite-datasource.db"))
    db.execute(<<SQL)
CREATE TABLE IF NOT EXISTS `favorite` (
  `user_id` integer NOT NULL,
  `message_id` integer NOT NULL,
  PRIMARY KEY  (`user_id`, `message_id`)
);
SQL
    plugin.add_event_filter(:favorited_by){ |message, users|
      begin
        key, val, = atomic{ db.execute2("select user_id from favorite where message_id=?" ,message[:id]) }
        if val and val.is_a? Enumerable
          val.each{ |user_id|
            users << User.findbyid(user_id.to_i)
          }
        end
      rescue Retriever::InvalidTypeError
      rescue SQLite3::SQLException => e
        warn e.inspect
        warn e.backtrace.inspect end
      [message, users] }
    plugin.add_event(:favorite){ |service, user, message|
      atomic{
        db.execute("insert or ignore into favorite (user_id, message_id) values (?, ?)", user[:id], message[:id]) } }
    plugin.add_event(:unfavorite){ |service, user, message|
      atomic{
        db.execute("delete from favorite where user_id = ? and message_id = ?", user[:id], message[:id]) } }

  end

  class SQLiteDataSource
    include Retriever::DataSource

    def initialize
      begin
        if not(FileTest.exist?(confroot("sqlite-datasource.db"))) or
            FileTest.writable_real?(confroot("sqlite-datasource.db"))
          @db = SQLite3::Database.new(File::expand_path(Config::CONFROOT + "sqlite-datasource.db"))
          atomic{ table_setting }
          @insert = "insert or ignore into #{table_name} (#{columns.join(',')}) values (#{columns.map{|x|'?'}.join(',')})"
          @update = "update #{table_name} set " + columns.slice(0, columns.size-1).map{|x| "#{x}=?"}.join(',') + " where id=?"
          @findbyid = "select * from #{table_name} where id=?"
          modelclass.add_data_retriever(self)
        else
          warn "sqlite database file #{Config::CONFROOT}sqlite-datasource.db is not writable."
        end
      rescue => e
        error "sqlite initialize failed. #{e}"
      end
    end

    def atomic
      @@mutex ||= Mutex.new
      @@mutex.synchronize{
        yield
      }
    end

    def findbyid(id)
      begin
        return findbyid_multi(id) if id.is_a? Array
        key, val, = atomic{ @db.execute2(@findbyid ,id) }
        return nil if not val
        return record_convert(key.zip(val))
      rescue Retriever::InvalidTypeError
        return nil
      rescue SQLite3::SQLException => e
        warn e.inspect
        warn e.backtrace.inspect
        return nil end end

    def findbyid_multi(ids)
      ids.map{|id| findbyid(id) }.select(&ret_nth(0)) end

    # def selectby(key, value)
    #   return [] if caller(1).include?(caller[0].first)
    #   begin
    #     keys, *rows = atomic{ @db.execute2("select * from #{table_name} where #{key} = ?" ,value) }
    #     return [] unless rows.is_a?(Array) and not(rows.empty?)
    #     return rows.map{ |row| record_convert(keys.zip(row)) }
    #   rescue Retriever::InvalidTypeError, Exception, RuntimeError => e
    #     return []
    #   rescue SQLite3::SQLException => e
    #     warn e.inspect
    #     warn e.backtrace.inspect
    #     return [] end end

    def record_convert(pairs)
      result = {}
      pairs.each{ |pair|
        if(pair[0].to_s.slice(-3, 3) == '_id')
          key = pair[0].to_s.slice(0, pair[0].to_s.length-3).to_sym
        else
          key = pair[0].to_sym end
        type = modelclass.keys.assoc(key)
        val = modelclass.cast(pair[1], type[1], type[2])
        # pair[1] = Time.parse(pair[1].to_s) if pair[0].to_sym == :created
        result[key] = val }
      result end

    def getid(obj)
      if(obj.is_a?(Retriever::Model))
        obj[:id]
      else
        obj end end

    def convert2id_all(src)
      result = {}
      src.each{ |pair|
        result[pair[0]] = getid(pair[1]) }
      result end

    def convert(modifier)
      columns.map{ |key|
        if /_id$/ === key.to_s
          key = key.to_s.slice(0, key.to_s.size-3).to_sym
          if(modifier[key].is_a? Integer)
            modifier[key]
          elsif modifier[key].respond_to?(:[])
            modifier[key][:id] || modifier[key]['id'] end
        elsif modifier[key].is_a?(Time)
          modifier[key].strftime('%Y-%m-%d %H:%M:%S')
        elsif modifier[key].is_a?(TrueClass)
          1
        elsif modifier[key].is_a?(FalseClass)
          0
        else
          modifier[key] end } end

    def merge(src, dst)
      src.update(dst){|k, s, d| d or s } end

    def store_datum(datum)
      assert_type(Hash, datum)
      begin
        prim = findbyid(datum[:id])
        if prim
          modifier, query = merge(prim, convert2id_all(datum)), @update
          return nil if (modifier.keys + prim.keys).uniq.all?{ |k| modifier[k] == prim[k] }
        else
          modifier, query = datum, @insert
        end
        atomic{ @db.execute(query, *convert(modifier)) }
      rescue SQLite3::SQLException => e
        warn e.inspect
        warn e.backtrace.inspect end end end

  class SQLiteMessageDataSource < SQLiteDataSource
    @@columns = [:user_id, :message, :receiver_id, :replyto_id, :retweet_id, :source, :geo, :exact,
                 :created, :id].freeze

    def modelclass
      Message end

    def columns
      @@columns end

    def table_name
      'messages' end

    def table_setting
      sql = <<SQL
CREATE TABLE IF NOT EXISTS `messages` (
  `id` integer NOT NULL,
  `user_id` integer default NULL,
  `message` text NOT NULL,
  `receiver_id` integer default NULL,
  `replyto_id` integer default NULL,
  `retweet_id` integer default NULL,
  `source` text,
  `geo` text,
  `exact` integer default 0,
  `created` text NOT NULL,
  PRIMARY KEY  (`id`)
);
SQL
      @db.execute(sql) end end

  class SQLiteUserDataSource < SQLiteDataSource
    @@columns = [:idname, :name, :location, :detail, :profile_image_url, :url, :protected,
                 :followers_count, :friends_count, :statuses_count, :id].freeze

    def modelclass
      User end

    def columns
      @@columns end

    def table_name
      'users' end

    def table_setting
      sql = <<SQL
CREATE TABLE IF NOT EXISTS `users` (
  `id` integer NOT NULL,
  `idname` text NOT NULL,
  `name` text,
  `location` text,
  `detail` text,
  `profile_image_url` text,
  `url` text,
  `protected` integer default 0,
  `followers_count` integer default NULL,
  `friends_count` integer default NULL,
  `statuses_count` integer default NULL,
  PRIMARY KEY  (`id`));
SQL
      @db.execute(sql) end end

  class SQLiteUserListDataSource < SQLiteDataSource
    @@columns = [:name, :mode, :description, :user_id, :slug, :id].freeze

    def modelclass
      UserList end

    def columns
      @@columns end

    def table_name
      'userlist' end

    def belong_users_id(userlist_id)
      r = atomic{ @db.execute("select user_id
                               from userlist_member
                               where userlist_id = ? ", userlist_id) }
      r.map{|row| row.first} if r end

    def belong_users(userlist_id)
      belong_users_id(userlist_id).map(&User.method(:findbyid)) end

    def belong?(userlist_id, user_id)
      atomic{
        @db.execute("select user_id
                     from userlist_member
                     where user_id = ? AND userlist_id = ? ", user_id, userlist_id){ |row|
          return row.first } }
      false end

    def record_convert(pairs)
      result = super(pairs)
      result[:member] = belong_users(result[:id])
      result end

    def store_datum(datum)
      if datum[:member].respond_to?(:map)
        datum[:member].each{ |u|
          atomic{
            @db.execute("insert or ignore into userlist_member (user_id, userlist_id)
                                values (?, ?)", u, datum[:id]) } } end
      super(datum)
    end

    def table_setting
      sql = <<SQL
CREATE TABLE IF NOT EXISTS `userlist_member` (
  `user_id` integer NOT NULL,
  `userlist_id` integer NOT NULL,
  PRIMARY KEY  (`user_id`, `userlist_id`));
SQL
      @db.execute(sql)
      sql = <<SQL
CREATE TABLE IF NOT EXISTS `userlist` (
  `id` integer NOT NULL,
  `name` text NOT NULL,
  `mode` integer,
  `description` text,
  `user_id` integer NOT NULL,
  `slug` text NOT NULL,
  PRIMARY KEY  (`id`));
SQL
      @db.execute(sql) end end

  class SQLiteFavoriteDataSource < SQLiteDataSource
    @@columns = [:user_id, :message_id, :created, :id].freeze

    def modelclass
      Message end

    def columns
      @@columns end

    def table_name
      'messages' end

    def table_setting
      sql = <<SQL
CREATE TABLE IF NOT EXISTS `messages` (
  `id` integer NOT NULL,
  `user_id` integer default NULL,
  `message` text NOT NULL,
  `receiver_id` integer default NULL,
  `replyto_id` integer default NULL,
  `retweet_id` integer default NULL,
  `source` text,
  `geo` text,
  `exact` integer default 0,
  `created` text NOT NULL,
  PRIMARY KEY  (`id`)
);
SQL
      @db.execute(sql) end end

  SQLiteMessageDataSource.new
  SQLiteUserDataSource.new
  SQLiteUserListDataSource.new

end
# ~> -:153: syntax error, unexpected $end, expecting kEND
