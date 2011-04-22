# -*- coding: utf-8 -*-
#
# Mikutter SQLite
#

# 以下のコマンドで、sqliteをインストールして下さい
# sudo aptitude install libsqlite3-dev ruby-dev
# gem install sqlite3-ruby

require File.expand_path('utils')
miquire :addon, 'settings'
miquire :core, 'environment'
miquire :core, 'user'
miquire :core, 'message'
miquire :core, 'userlist'
miquire :core, 'retriever'
miquire :core, 'serialthread'

require_if_exist 'sqlite3'

if defined? SQLite3

  require File.join(File.dirname(__FILE__), 'messagedatasource')
  require File.join(File.dirname(__FILE__), 'userdatasource')
  require File.join(File.dirname(__FILE__), 'userlistdatasource')
  require File.join(File.dirname(__FILE__), 'favoritedatasource')

  Module.new do
    plugin = Plugin.create(:sqlite)
    @db = SQLite3::Database.new(File::expand_path(Environment::CONFROOT + "sqlite-datasource.db"))

    def self.data_retrieve_hook(filter_name, table_name, key, extract_key)
      sql = "select #{extract_key} from #{table_name} where #{key}=?"
      Plugin.create(:sqlite).add_event_filter(filter_name){ |message, children|
        begin
          key, *vals = SQLiteDataSource.transaction{ @db.execute2(sql ,message[:id]) }
          if vals and vals.is_a? Enumerable
            vals.each{ |the_id|
              children << yield(the_id.first.to_i) } end
        rescue Retriever::InvalidTypeError, SQLite3::SQLException => e
          error e end
        [message, children] } end

    data_retrieve_hook(:favorited_by, 'favorite', 'message_id', 'user_id', &User.method(:findbyid))
    data_retrieve_hook(:replied_by, 'messages', 'replyto_id', 'id', &Message.method(:findbyid))
    data_retrieve_hook(:retweeted_by, 'messages', 'retweet_id', 'id', &Message.method(:findbyid))

  end

  SQLiteMessageDataSource.new
  SQLiteUserDataSource.new
  SQLiteUserListDataSource.new

end
# ~> -:153: syntax error, unexpected $end, expecting kEND
