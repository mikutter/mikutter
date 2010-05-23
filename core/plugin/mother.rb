#
# MotherPlugin
# プラグインを動かすためのプラグイン。
#

miquire :plugin, 'plugin'
miquire :core, 'autotag'

module Plugin
  class Mother < Plugin

    # generate cache storage
    def self.cache
      buffer = Array.new
      lambda{ |other|
        if buffer.include?(other) then
          true
        else
          buffer.push(other)
          false
        end
      }
    end
    private_class_method :cache

    # arglist such as [[watch, message] ... ]
    def self.message_receive_events(*names)
      names.each{ |name|
        cache_storage = cache
        define_method(name){ |arglist|
          self.plugin_call(name, arglist.select{ |a|
                             a[1][:rule] == :destroy or not(cache_storage.call(a[1][:id])) })
        }
      }
    end
    private_class_method :message_receive_events

    def boot(arglist)
      plugin_call(:boot, arglist)
    end

    # arglist such as [[plugin_name, watch, command, *message] ... ]
    def plugincall(arglist)
      plugin_alist = Hash.new{ [] }
      arglist.each{ |args|
        plugin_name, *remain = args
        plugin_alist[plugin_name] = plugin_alist[plugin_name].push(remain)
      }
      plugin_alist.each{ |plugin_name, args|
        if(plugin_name) then
          self.fire(:plugincall, Ring::avail_plugins(:all)[plugin_name.to_sym], args)
        else
          self.plugin_call(:plugincall, args)
        end
      }
    end

    def period(arglist)
      plugin_call(:period, arglist)
    end

    # arglist such as [[watch, message] ... ]
    #def call(ring, arglist)
    #  if message[:tags] then
    #    called = false
    #    primary = message[:tags].first
    #    ring[:call].each {|item|
    #      notice "#{primary} == #{item.call_tag} = "+(primary == item.call_tag).inspect
    #      if(primary == item.call_tag) then
    #        called = true
    #        self.fire(:call, item, watch, message)
    #      end
    #    }
    #  end
    #  return called
    #end

    message_receive_events :update, :mention, :followed, :mypost

    def plugin_call(handler, arglist)
      return nil if arglist.empty?
      Ring[handler].each { |item|
        self.fire(handler, item, arglist) }
    end

    def fire(handler, item, arglist)
      notice "#{handler.to_s}(#{item.class})"
      item.__send__(handler, arglist)
    end

  end
end
