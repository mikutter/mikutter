
miquire :plugin, 'plugin'
miquire :core, 'post'
miquire :core, 'utils'
miquire :core, 'environment'
miquire :core, 'userconfig'

require 'singleton'
require 'set'
require 'pp'

class Watch
  include Singleton

  def self.scan_and_yield(handler)
    lambda {|name, post, options|
      mumbles = post.scan(handler, options)
      yield(name, post, mumbles) if mumbles
    }
  end

#   def self.scan_and_fire(handler)
#     self.scan_and_yield(handler){ |name, post, message|
#       Plugin::Ring.reserve(name, messages.map{ |m| [post, m] }) if messages
#     }
#   end

  def get_events
    event_booking = Hash.new{ |h, k| h[k] = [] }
    return {
      :period => {
        :interval => 1,
        :proc => lambda {|name, post, messages|
          unless messages then
            Plugin.call(name, post)
          end
        }
      },
      :update => {
        :interval => UserConfig[:retrieve_interval_friendtl],
        :options => {:count => UserConfig[:retrieve_count_friendtl]},
        :proc => Watch.scan_and_yield(:friends_timeline){ |name, post, messages|
          event_booking[:update].concat(messages)
          event_booking[:mention].concat(messages.select{ |m| m.to_me? })
          event_booking[:mypost].concat(messages.select{ |m| m.from_me? })
        }
      },
      :mention => {
        :interval => UserConfig[:retrieve_interval_mention],
        :options => {:count => UserConfig[:retrieve_count_mention]},
        :proc => Watch.scan_and_yield(:replies){ |name, post, messages|
          event_booking[:update].concat(messages)
          event_booking[:mention].concat(messages)
          event_booking[:mypost].concat(messages.select{ |m| m.from_me? })
        }
      },
#       :followed => {
#         :interval => UserConfig[:retrieve_interval_followed],
#         :options => {
#           :count => UserConfig[:retrieve_count_followed],
#           :no_auto_since_id => true,
#         },
#         :proc => lambda{ |name, service, options|
#           next_cursor = -1
#           users = []
#           while(next_cursor and next_cursor != 0)
#             res, raw = service.scan(:followers,
#                                     :id => service.user,
#                                     :get_raw_text => true,
#                                     :cursor => next_cursor)
#             break if not res
#             users.concat(res.reverse)
#             next_cursor = raw['next_cursor'] end
#           Plugin.call(:followed, service, users.reverse) if not users.empty? } }
    }, lambda{ event_booking } end

  def initialize()
    @counter = 0
    @post = Post.new
    @received = Hash.new{ |h, k| h[k] = Set.new }
    Plugin.call(:boot, @post)
  end

  def action
    events, booking = get_events
    Thread.new(@counter){ |counter|
      threads = ThreadGroup.new
      events.each_pair{ |name, event|
        if((counter % event[:interval]) == 0)
          threads.add Thread.new(name, event){ |name, event|
            event[:proc].call(name, @post, event[:options])
          }
        end
      }
      threads.list.each{ |t| t.join }
      booking.call.each_pair{ |k, v|
        messages = v.uniq.select{ |n| not @received[k].include?(n) }
        @received[k].merge(messages)
        Plugin.call(k, @post, messages) } }
    @counter += 1
  end

  def get_posts(api, options={})
    @post.scan(api, options)
  end

end
