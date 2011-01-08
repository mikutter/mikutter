# -*- coding: utf-8 -*-
#! /usr/bin/ruby

require 'utils'
require 'environment'
require 'watch'
require 'post'
require 'yaml'

def boot()
  puts Environment::ACRO + ' initializer'
  puts Environment::ACRO + ' require a twitter account. Get twitter account by http://twitter.com/ .'
  user, pass = twitter_account()
  if not(FileTest.directory?(File.expand_path(Environment::CONFROOT))) then
    Dir.mkdir(File.expand_path(Environment::CONFROOT))
  end
  YAML.dump({'user'=>user, 'passwd' => pass}, open(File.expand_path("#{Environment::CONFROOT}account"), 'w'))
  puts 'Complete. you can run Mikutter "./mikutter.rb".'
  puts 'see http://toshia.dip.jp/mikutter/ (coming soon)'
  puts 'enjoy.'
end

def twitter_account
  print 'User name? >'
  $stdout.flush
  user = gets().chomp
  print 'password? >'
  $stdout.flush
  pass = gets().chomp
  print 'connecting... '
  twitter = Twitter.new(user, pass)
  tl = nil
  while(not tl.is_a?(Net::HTTPResponse))
    tl = twitter.friends_timeline()
  end
  if(tl.code != '200') then
    puts 'Authentication failed. Username and Password is valid?'
    return twitter_account()
  end
  puts 'Accepted.'
  return user, pass
end

boot()
