# -*- coding: utf-8 -*-
module Memoize
   # The version of the memoize library
   MEMOIZE_VERSION = '1.3.1'
   
   # Memoize the method +name+.  If +file+ is provided, then the method results
   # are stored on disk as well as in memory.
   def memoize(name, file=nil)
      cache = File.open(file, 'rb'){ |io| Marshal.load(io) } rescue {}

      (class<<self; self; end).send(:define_method, name) do |*args|
         unless cache.has_key?(args)
            cache[args] = super(*args)
            File.open(file, 'wb'){ |f| Marshal.dump(cache, f) } if file
         end
         cache[args]
      end
      cache
   end
end
