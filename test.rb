# -*- coding: utf-8 -*-
#! /usr/bin/ruby

Dir.glob(File.dirname(__FILE__) + '/core/test/test_*').each{ |f|
  unless system("ruby #{f}")
    puts "test failed #{f}"
    abort
  end
}

puts 'all test case passed'

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
