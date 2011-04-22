# -*- coding: utf-8 -*-

require File.join(File.dirname(__FILE__), 'datasource')

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
    transaction{
      db.execute(sql) } end end
