# -*- coding: utf-8 -*-

require File.join(File.dirname(__FILE__), 'datasource')

class SQLiteFavoriteDataSource < SQLiteDataSource
  @@columns = [:user_id, :message_id].freeze

  def modelclass
    Message end

  def columns
    @@columns end

  def table_name
    'favorite' end

  def table_setting
    begin
      @db.execute(<<SQL)
CREATE TABLE IF NOT EXISTS `favorite` (
  `user_id` integer NOT NULL,
  `message_id` integer NOT NULL,
  PRIMARY KEY  (`user_id`, `message_id`)
);
SQL
    rescue SQLite3::SQLException => e
      warn e end
    transaction{ @db.execute(sql) } end end

# Module.new do
#   plugin = Plugin.create(:sqlite)

#   plugin.add_event(:favorite){ |service, user, message|
#     SerialThread.new{
#       begin
#         SQLiteDataSource.transaction{
#           @db.execute("insert or ignore into favorite (user_id, message_id) values (?, ?)", user[:id], message[:id]) }
#       rescue SQLite3::SQLException => e
#         warn e end } }
#   plugin.add_event(:unfavorite){ |service, user, message|
#     SerialThread.new{
#       begin
#         SQLiteDataSource.transaction{
#           @db.execute("delete from favorite where user_id = ? and message_id = ?", user[:id], message[:id]) }
#       rescue SQLite3::SQLException => e
#         warn e end } } end

