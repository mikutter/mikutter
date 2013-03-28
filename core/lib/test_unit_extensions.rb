# -*- coding: utf-8 -*-

module Test::Unit
  # Used to fix a minor minitest/unit incompatibility in flexmock 
  
  class TestCase
   
    def self.must(name, &block)
      test_name = "test_#{name.gsub(/\s+/,'_')}".to_sym
      defined = instance_method(test_name) rescue false
      raise "#{test_name} is already defined in #{self}" if defined
      if block_given?
        define_method(test_name, &block)
      else
        define_method(test_name) do
          flunk "No implementation provided for #{name}"
        end
      end
    end

  end
end

module Mopt
  extend Mopt

  @opts = {
    debug: true,
    testing: true,
    error_level: 3 }

  def method_missing(key)
    scope = class << self; self end
    scope.__send__(:define_method, key){ @opts[key.to_sym] }
    @opts[key.to_sym] end

end
