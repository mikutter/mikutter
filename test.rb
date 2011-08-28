# -*- coding: utf-8 -*-
#! /usr/bin/ruby

successed = []
failed = []
processes = {}

Dir.glob(File.dirname(__FILE__) + '/core/test/test_*').each{ |f|
  processes[fork { require File.expand_path(f) }] = f }

Process.waitall.each{ |pid, stat|
  (stat.success? ? successed : failed) << processes[pid]
}

puts "#{successed.size} test cases successed #{successed.join(', ')}"
puts "#{failed.size} test cases failed #{failed.join(', ')}"

# >> Loaded suite ./core/test/test_user
# >> Started
# >> .
# >> Finished in 0.317922 seconds.
# >> 
# >> 1 tests, 2 assertions, 0 failures, 0 errors
# >> Loaded suite ./core/test/test_utils
# >> Started
# >> .
# >> Finished in 0.000802 seconds.
# >> 
# >> 1 tests, 1 assertions, 0 failures, 0 errors
# >> Loaded suite ./core/test/test_retriever
# >> Started
# >> .
# >> Finished in 0.000387 seconds.
# >> 
# >> 1 tests, 1 assertions, 0 failures, 0 errors
# >> Loaded suite ./core/test/test_message
# >> Started
# >> .
# >> Finished in 0.002613 seconds.
# >> 
# >> 1 tests, 9 assertions, 0 failures, 0 errors
# >> all test case passed
