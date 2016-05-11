# -*- coding: utf-8 -*-
module Retriever
  @@cast = {
    :int => lambda{ |v| begin v.to_i; rescue NoMethodError then raise InvalidTypeError end },
    :bool => lambda{ |v| !!(v and not v == 'false') },
    :string => lambda{ |v| begin v.to_s; rescue NoMethodError then raise InvalidTypeError end },
    :time => lambda{ |v|
      if not v then
        nil
      elsif v.is_a? String then
        Time.parse(v)
      else
        Time.at(v)
      end
    }
  }

  def self.cast_func(type)
    @@cast[type]
  end

end

