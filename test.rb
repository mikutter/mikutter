#! /usr/bin/ruby
# -*- coding: utf-8 -*-

successed = []
failed = []
processes = {}

Dir.glob(File.dirname(__FILE__) + '/test/core/test_*').each{ |f|
  processes[fork { require File.expand_path(f) }] = f }

Process.waitall.each{ |pid, stat|
  (stat.success? ? successed : failed) << processes[pid]
}

puts "#{successed.size} test cases successed #{successed.join(', ')}"
puts "#{failed.size} test cases failed #{failed.join(', ')}"

exit failed.size
