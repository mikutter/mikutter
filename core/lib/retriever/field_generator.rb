# -*- coding: utf-8 -*-

class Retriever::FieldGenerator
  def initialize(model_klass)
    @model_klass = model_klass
  end

  def int(field_name, required: false)
    @model_klass.add_field(field_name, type: :int, required: required)
  end

  def string(field_name, required: false)
    @model_klass.add_field(field_name, type: :string, required: required)
  end

  def bool(field_name, required: false)
    @model_klass.add_field(field_name, type: :bool, required: required)
  end

  def time(field_name, required: false)
    @model_klass.add_field(field_name, type: :time, required: required)
  end

  def uri(field_name, required: false)
    @model_klass.add_field(field_name, type: :uri, required: required)
  end

  def has(field_name, type, required: false)
    @model_klass.add_field(field_name, type: type, required: required)
  end
end








