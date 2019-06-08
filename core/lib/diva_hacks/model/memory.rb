# -*- coding: utf-8 -*-
class Diva::Model::Memory
  include Diva::DataSource

  def initialize(klass=Diva::Model)
    @storage = WeakStorage.new(Integer, klass, name: "diva-model-memory(#{klass})") end

  def findbyid(id, policy)
    if id.is_a? Enumerable
      id.map{ |i| @storage[i.to_i] }
    else
      @storage[id.to_i] end
  end

  def store_datum(datum)
    @storage[datum.id] = datum
  end
end
