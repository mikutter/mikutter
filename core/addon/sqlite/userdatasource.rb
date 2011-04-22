# -*- coding: utf-8 -*-

require File.join(File.dirname(__FILE__), 'datasource')

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
    transaction{
      @db.execute(sql) } end end
