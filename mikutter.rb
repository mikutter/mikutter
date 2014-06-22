#! /usr/bin/ruby
# -*- coding: utf-8 -*-
=begin rdoc
= mikutter - the moest twitter client
Copyright (C) 2009-2014 Toshiaki Asai

This software is released under the MIT License.

http://opensource.org/licenses/mit-license.php

=end
mikutter_directory = File.expand_path(File.dirname(__FILE__))

unless ENV['DISABLE_BUNDLER_SETUP']
  begin
    ENV['BUNDLE_GEMFILE'] = File.expand_path(File.join(File.dirname($0), "Gemfile"))
    require 'bundler/setup'
  rescue LoadError, SystemExit
    # bundlerがないか、依存関係の解決に失敗した場合
    # System の gem を使ってみる
  end
end

Thread.abort_on_exception = true
ENV['LIBOVERLAY_SCROLLBAR'] = '0'

require 'benchmark'
require 'webrick'
require 'thread'
require 'fileutils'

require File.expand_path(File.join(mikutter_directory, 'core/boot/option'))
require File.expand_path(File.join(mikutter_directory, 'core/utils'))

miquire :boot, 'check_config_permission', 'mainloop', 'delayer'
miquire :core, 'service', 'environment'
Dir.chdir(Environment::CONFROOT)
miquire :boot, 'load_plugin'

notice "fire boot event"
Plugin.call(:boot, Post.primary_service)

# イベントの待受を開始する。
# _profile_ がtrueなら、プロファイリングした結果を一時ディレクトリに保存する
def boot!(profile)
  begin
    Mainloop.before_mainloop
    if profile
      require 'ruby-prof'
      begin
        notice 'start profiling'
        RubyProf.start
        Mainloop.mainloop
      ensure
        result = RubyProf.stop
        printer = RubyProf::CallTreePrinter.new(result)
        profile_out = File.join(File.expand_path(Environment::TMPDIR), 'profile-'+Time.new.strftime('%Y-%m-%d-%H%M%S')+'.out')
        notice "profile: writing to #{profile_out}"
        printer.print(File.open(profile_out, 'w'), {})
        notice "profile: done."
      end
    else
      Mainloop.mainloop end
  rescue => exception
    into_debug_mode(exception)
    notice "catch exception `#{exception.class}'"
    raise exception
  rescue Exception => exception
    notice "catch exception `#{exception.class}'"
    exception = Mainloop.exception_filter(exception)
    notice "=> `#{exception.class}'"
    raise exception end
  exception = Mainloop.exception_filter(nil)
  if exception
    notice "raise mainloop exception `#{exception.class}'"
    raise exception end
  notice "boot! exited normally." end

def error_handling!(exception)
  notice "catch #{exception.class}"
  File.open(File.expand_path(File.join(Environment::TMPDIR, 'crashed_exception')), 'w'){ |io| Marshal.dump(exception, io) }
  raise exception end

begin
  errfile = File.join(File.expand_path(Environment::TMPDIR), 'mikutter_dump')
  File.rename(errfile, File.expand_path(File.join(Environment::TMPDIR, 'mikutter_error'))) if File.exist?(errfile)
  if not Mopt.debug
    $stderr = File.open(errfile, 'w')
    def $stderr.write(string)
      super(string)
      self.fsync rescue nil end end
  boot!(Mopt.profile)
  if(Delayer.exception)
    raise Delayer.exception end
rescue Interrupt, SystemExit, SignalException => exception
  notice "catch #{exception.class}"
  if Delayer.exception
    error_handling! Delayer.exception
  else
    File.delete(errfile) if File.exist?(errfile)
    raise exception end
rescue Exception => exception
  error_handling! exception end
notice "mainloop exited normally."
