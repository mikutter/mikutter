# -*- coding: utf-8 -*-
require 'test/unit'
require File.expand_path(File.dirname(__FILE__) + '/../helper')
# require File.expand_path(File.dirname(__FILE__) + '/../utils')
miquire :core, 'retriever'

class Message < Retriever::Model
  self.keys = [[:id, :int, :required],
               [:title, :string],
               [:desc, :string],
               [:replyto, Message],
               [:created, :time]]

end

class TC_DataRetriever < Test::Unit::TestCase

  def test_generate
    a = Message.new_ifnecessary(:id => 1, :title => 'hello')
    assert_kind_of(Message, a)
  end

end
# >> Loaded suite -
# >> Started
# >> .
# >> Finished in 0.000582 seconds.
# >> 
# >> 1 tests, 1 assertions, 0 failures, 0 errors
