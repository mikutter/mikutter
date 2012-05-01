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

exit failed.size
