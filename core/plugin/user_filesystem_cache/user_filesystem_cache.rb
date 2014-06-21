# -*- coding: utf-8 -*-
require 'moneta'

module Plugin::UserFilesystemCache
  class Cache
    DEFAULT_EXPIRE = (24 * 60 * 60) * 30 # 30 days

    class << self
      attr_accessor :keys
    end

    include Retriever::DataSource

    def initialize
      @db = ::Moneta.build do
        use :Expires, expires: UserConfig[:user_filesystem_cache_expire] || DEFAULT_EXPIRE
        use :Transformer, key: :md5, value: :marshal
        adapter SpreadFileAdapter, dir: File.join(Environment::CACHE, 'user_filesystem_cache')
      end
    end

    def findbyid(id)
      case id
      when Enumerable
        id.map{|_|@db[_.to_s]}.compact
      when Integer
        @db[id.to_s]
      else
        nil end end

    def store_datum(datum)
      @db.store(datum[:id].to_s, datum)# expires: EXPIRE)
    end

    class SpreadFileAdapter < Moneta::Adapters::File
      def store_path(key)
        ::File.join(@dir, key[0], key[1], key)
      end
    end

  end
  User.add_data_retriever Cache.new
end


Plugin.create(:user_filesystem_cache) do
  
end
