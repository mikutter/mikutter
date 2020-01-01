#!/bin/sh
# -*- coding: utf-8 -*-
exec ruby -x "$0" "$@"
#!ruby
=begin rdoc
= mikutter - simple, powerful and moeful Mastodon client
Copyright (C) 2009-2020 Toshiaki Asai

This software is released under the MIT License.

http://opensource.org/licenses/mit-license.php

=end
module Mikutter; end

require_relative 'core/boot/option'
Mopt.parse exec_command: true

if !ENV['DISABLE_BUNDLER_SETUP'] || ['', '0'].include?(ENV['DISABLE_BUNDLER_SETUP'].to_s)
  begin
    ENV['BUNDLE_GEMFILE'] = File.expand_path(File.join(File.dirname($0), "Gemfile"))
    require 'bundler/setup'
  rescue LoadError, SystemExit
    # bundlerがないか、依存関係の解決に失敗した場合
    # System の gem を使ってみる
  end
end

ENV['LIBOVERLAY_SCROLLBAR'] = '0'

require 'benchmark'
require 'webrick'
require 'thread'
require 'fileutils'

require_relative 'core/miquire'

require 'lib/diva_hacks'
require 'lib/lazy'
require 'lib/reserver'
require 'lib/timelimitedqueue'
require 'lib/uithreadonly'
require 'lib/weakstorage'

require_relative 'core/utils'

require 'boot/check_config_permission'
require 'boot/mainloop'
require 'boot/delayer'
require 'environment'

Dir.chdir(Environment::CONFROOT)

require 'system/system'

require 'boot/load_plugin'

Plugin.call(:boot, nil)

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
        path = File.join(Environment::TMPDIR, 'profile', Time.new.strftime('%Y-%m-%d-%H%M%S'))
        FileUtils.mkdir_p(path)
        notice "profile: writing to #{path}"
        printer.print(path: path)
        notice "profile: done."
      end
    else
      Mainloop.mainloop end
  rescue => exception
    into_debug_mode(exception)
    notice "catch exception `#{exception.class}'"
    raise
  rescue Exception => exception
    notice "catch exception `#{exception.class}'"
    exception = Mainloop.exception_filter(exception)
    notice "=> `#{exception.class}'"
    raise end
  exception = Mainloop.exception_filter(nil)
  if exception
    notice "raise mainloop exception `#{exception.class}'"
    raise exception end
  notice "boot! exited normally." end

def error_handling!(exception)
  notice "catch #{exception.class}"
  if Mopt.debug && exception.respond_to?(:deferred) && exception.deferred
    if command_exist?('dot')
      notice "[[#{exception.deferred.graph_draw}]]"
    else
      notice exception.deferred.graph
    end
  end
  File.open(File.expand_path(File.join(Environment::TMPDIR, 'crashed_exception')), 'w'){ |io| Marshal.dump(exception, io) } rescue nil
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
