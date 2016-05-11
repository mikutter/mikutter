# -*- coding: utf-8 -*-
class Retriever::Model::Memory
  include Retriever::DataSource

  def initialize(storage)
    @storage = storage end

  def findbyid(id)
    if id.is_a? Array or id.is_a? Set
      id.map{ |i| @storage[i.to_i] }
    else
      @storage[id.to_i] end
  end

end
