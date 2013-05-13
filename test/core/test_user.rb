# -*- coding: utf-8 -*-
require 'test/unit'
require File.expand_path(File.dirname(__FILE__) + '/../helper')
#require File.expand_path(File.dirname(__FILE__) + '/../utils')
miquire :core, 'user'
miquire :core, 'plugin'
require 'benchmark'

$debug = 2

class TC_User < Test::Unit::TestCase
  def setup
  end

  def test_findbyid # !> ambiguous first argument; put parentheses or even spaces

  end

end
