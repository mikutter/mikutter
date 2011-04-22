# -*- coding: utf-8 -*-

require 'thread'
require 'set'
require 'timeout'

class SQLiteDataSource
  include Retriever::DataSource

  @@db = begin
           if not(FileTest.exist?(confroot("sqlite-datasource.db"))) or
               FileTest.writable_real?(confroot("sqlite-datasource.db"))
             SQLite3::Database.new(File::expand_path(Environment::CONFROOT + "sqlite-datasource.db"))
           else
             warn "sqlite database file #{Environment::CONFROOT}sqlite-datasource.db is not writable."
             nil
           end
         rescue => e
           error "sqlite initialize failed. #{e}"
           nil
         end

  @@transaction = Monitor.new

  @@queue = Queue.new

  Thread.new{
    loop{
      stock = Set.new
      catch(:write){
        loop{
          if(stock.empty?)
            poped = @@queue.pop
          else
            begin
              timeout(5){
                poped = @@queue.pop }
            rescue Timeout::Error
              throw :write end end
          stock << poped
          # notice "sqlite: stocked(#{stock.size})"
          if stock.size > 1024
            throw :write end } }
      # notice "sqlite: write #{stock.size} query"
      @@transaction.synchronize{
        @@db.transaction{
          stock.each{ |query|
            @@db.execute(*query) } } }
      # notice "sqlite: wrote"
    } }

  def self.transaction
    @@transaction.synchronize(&Proc.new)
  end

  def transaction
    SQLiteDataSource.transaction(&Proc.new)
    # @@transaction.synchronize(&Proc.new)
  end

  def initialize
    begin
      if not(FileTest.exist?(confroot("sqlite-datasource.db"))) or
          FileTest.writable_real?(confroot("sqlite-datasource.db"))
        transaction{ table_setting }
        @insert = "insert or ignore into #{table_name} (#{columns.join(',')}) values (#{columns.map{|x|'?'}.join(',')})"
        @update = "update #{table_name} set " + columns.slice(0, columns.size-1).map{|x| "#{x}=?"}.join(',') + " where id=?"
        @findbyid = "select * from #{table_name} where id=?"
        modelclass.add_data_retriever(self)
      else
        warn "sqlite database file #{Environment::CONFROOT}sqlite-datasource.db is not writable."
      end
    rescue => e
      error "sqlite initialize failed. #{e}"
    end
  end

  def db
    @@db
  end

  def findbyid(id)
    # notice "sqlite: fetch #{self.class.to_s} (#{id.inspect})"
    begin
      return findbyid_multi(id) if id.is_a? Array
      key, val, = transaction{ db.execute2(@findbyid ,id) }
      return nil if not val
      return record_convert(key.zip(val))
    rescue Retriever::InvalidTypeError
      return nil
    rescue SQLite3::SQLException => e
      warn e
      return nil end end

  def findbyid_multi(ids)
    ids.map{|id| findbyid(id) }.select(&ret_nth(0)) end

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
        elsif modifier[key].respond_to?(:[]) and not modifier[key].is_a?(String)
          pp modifier[key]
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
    SerialThread.new{
      begin
        prim = findbyid(datum[:id])
        catch(:store_datum_exit){
          if prim
            modifier, query = merge(prim, convert2id_all(datum)), @update
            throw(:store_datum_exit) if (modifier.keys + prim.keys).uniq.all?{ |k| modifier[k] == prim[k] }
          else
            modifier, query = datum, @insert
          end
          @@queue << [query, *convert(modifier)]
          # transaction{ db.execute(query, *convert(modifier)) }
        }
      rescue SQLite3::SQLException => e
        warn e end } end end
# ~> -:44: syntax error, unexpected '}', expecting kEND
# ~> -:156: syntax error, unexpected $end, expecting '}'
