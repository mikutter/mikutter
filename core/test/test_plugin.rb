# -*- coding: utf-8 -*-

require 'test/unit'
require File.expand_path(File.expand_path(File.dirname(__FILE__) + '/../utils'))
miquire :plugin, 'plugin'
miquire :core, 'message'

require 'pp'

$debug = true
$debug_avail_level = 3
 # !> `*' interpreted as argument prefix
class TC_Plugin < Test::Unit::TestCase

  def test_filter
    plg = Plugin.create(:test)
    plg.add_event_filter(:update){ |x, ary| [x, ary.select{ |x| x[:message] == 'qun' }] }
    plg.add_event(:update){ |x, ary|
      assert_kind_of(Array, ary)
      # assert_equal(1, ary.size)
      p ary.size
    }
    Plugin.call(:update, nil, [Message.new(:system => true, :message => 'moe'),
                               Message.new(:system => true, :message => 'moe'),
                               Message.new(:system => true, :message => 'qun')])
    Delayer.run
  end

end
# >> Loaded suite -
# >> Started
# >> [[#<Plugin::PluginTag:0x7f54f17516e0 @name=:core, @status=:active>,
# >>   #<Proc:0x00007f54f1777958@./plugin/plugin.rb:278>],
# >>  3,
# >>  3]
# >> [[#<Plugin::PluginTag:0x7f54e6c4aeb8 @name=:test, @status=:active>,
# >>   #<Proc:0x00007f54f42d8c28@-:17>],
# >>  3,
# >>  1]
# >> 1
# >> .
# >> Finished in 0.005362 seconds.
# >> 
# >> 1 tests, 1 assertions, 0 failures, 0 errors
