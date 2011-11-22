#! /usr/bin/ruby
# -*- coding: utf-8 -*-
=begin rdoc
= mikutter - the moest twitter client
Copyright (C) 2009-2010 Toshiaki Asai

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

=end

Dir.chdir(File.join(File.dirname($0), 'core'))
Thread.abort_on_exception = true
ENV['LIBOVERLAY_SCROLLBAR'] = '0'

require 'benchmark'
require 'webrick'
require 'thread'
require 'fileutils'

require File.expand_path('boot/option')
require File.expand_path('utils')

miquire :boot, 'check_config_permission'
miquire :core, 'post'
miquire :boot, 'load_plugin'

notice "fire boot event"
Plugin.call(:boot, Post.primary_service)

Gtk.timeout_add(100){
  Delayer.run
  true }

# イベントの待受を開始する。
# _profile_ がtrueなら、プロファイリングした結果を一時ディレクトリに保存する
def boot!(profile)
  if profile
    require 'ruby-prof'
    begin
      RubyProf.start
      Gtk.main
    ensure
      result = RubyProf.stop
      printer = RubyProf::CallTreePrinter.new(result)
      printer.print(File.open(File.join(File.expand_path(Environment::TMPDIR), 'profile-'+Time.new.strftime('%Y-%m-%d-%H%M%S')+'.out'), 'w'), {}) end
  else
    Gtk.main end end


begin
  errfile = File.join(File.expand_path(Environment::TMPDIR), 'mikutter_dump')
  File.rename(errfile, File.expand_path(File.join(Environment::TMPDIR, 'mikutter_error'))) if File.exist?(errfile)
  if not Mopt.debug
    $stderr = File.open(errfile, 'w')
    def $stderr.write(string)
      super(string)
      self.fsync rescue nil end end
  boot!(Mopt.profile)
rescue Interrupt => e
  File.delete(errfile) if File.exist?(errfile)
  raise e
rescue Exception => e
  m = e.backtrace.first.match(/(.+?):(\d+)/)
  file_put_contents(File.join(File.expand_path(Environment::TMPDIR), 'crashed_file'), m[1])
  file_put_contents(File.join(File.expand_path(Environment::TMPDIR), 'crashed_line'), m[2])
  raise e
end
