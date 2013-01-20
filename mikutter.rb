#! /usr/bin/ruby
# -*- coding: utf-8 -*-
=begin rdoc
= mikutter - the moest twitter client
Copyright (C) 2009-2013 Toshiaki Asai

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

=end

if File.symlink?($0)
  Dir.chdir(File.join(File.dirname(File.readlink($0)), 'core'))
else
  Dir.chdir(File.join(File.dirname($0), 'core'))
end

Thread.abort_on_exception = true
ENV['LIBOVERLAY_SCROLLBAR'] = '0'

require 'benchmark'
require 'webrick'
require 'thread'
require 'fileutils'

require File.expand_path('boot/option')
require File.expand_path('utils')

miquire :boot, 'check_config_permission', 'mainloop'
miquire :core, 'service'
miquire :boot, 'load_plugin'

notice "fire boot event"
Plugin.call(:boot, Post.primary_service)

# イベントの待受を開始する。
# _profile_ がtrueなら、プロファイリングした結果を一時ディレクトリに保存する
def boot!(profile)
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
rescue => e
  into_debug_mode(e)
  raise e
rescue Exception => e
  e = Mainloop.exception_filter(e)
  notice e.class
  raise e
end

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
rescue Interrupt, SystemExit => e
  File.delete(errfile) if File.exist?(errfile)
  raise e
rescue SignalException => e
  File.delete(errfile) if File.exist?(errfile)
  raise e
rescue Exception => e
  object_put_contents(File.join(File.expand_path(Environment::TMPDIR), 'crashed_exception'), e) rescue nil
  raise e
end
