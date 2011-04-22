# -*- coding: utf-8 -*-

require File.join(File.dirname(__FILE__), 'datasource')

class SQLiteUserListDataSource < SQLiteDataSource
  @@columns = [:name, :mode, :description, :user_id, :slug, :id].freeze

  def modelclass
    UserList end

  def columns
    @@columns end

  def table_name
    'userlist' end

  def belong_users_id(userlist_id)
    begin
      r = transaction{ db.execute("select user_id
                                      from userlist_member
                                      where userlist_id = ? ", userlist_id) }
      r.map{|row| row.first} if r
    rescue SQLite3::SQLException => e
      warn e
      nil end end

  def belong_users(userlist_id)
    belong_users_id(userlist_id).map(&User.method(:findbyid)) end

  def belong?(userlist_id, user_id)
    begin
      transaction{
        db.execute("select user_id
                       from userlist_member
                       where user_id = ? AND userlist_id = ? ", user_id, userlist_id){ |row|
          return row.first } }
      false
    rescue SQLite3::SQLException => e
      warn e
      nil end end

  def record_convert(pairs)
    result = super(pairs)
    result[:member] = belong_users(result[:id])
    result end

  def store_datum(datum)
    if datum[:member].respond_to?(:map)
      datum[:member].each{ |u|
        begin
          transaction{
            db.execute("insert or ignore into userlist_member (user_id, userlist_id)
                                            values (?, ?)", u, datum[:id]) }
        rescue SQLite3::SQLException => e
          warn e end } end
    super(datum) end

  def table_setting
    transaction{
      sql = <<SQL
CREATE TABLE IF NOT EXISTS `userlist_member` (
  `user_id` integer NOT NULL,
  `userlist_id` integer NOT NULL,
  PRIMARY KEY  (`user_id`, `userlist_id`));
SQL
      db.execute(sql)
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
      db.execute(sql) } end end
