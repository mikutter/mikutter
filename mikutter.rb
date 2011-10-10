#! /usr/bin/ruby
# -*- coding: utf-8 -*-
=begin rdoc
= mikutter - the moest twitter client
Copyright (C) 2009-2010 Toshiaki Asai

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

=end

ENV['LIBOVERLAY_SCROLLBAR'] = '0'

def argument_parser()
  $debug = false
  $learnable = true
  $daemon = false
  $interactive = false
  $quiet = false
  $single_thread = false
  $skip_version_check = false

  ARGV.each{ |arg|
    case arg
    when '-i' # インタラクティブモード(default:off)
      $interactive = true
    when '--debug' # デバッグモード(default:off)
      $debug = true
    when '--no-cairo'
      $cairo = false
    when '-d' # デーモンモード(default:off)
      $daemon = true
    when '-l' # タグを学習しない(default:する)
      $learnable = false
    when '-q'
      $quiet = true
    when '-s' # シングルスレッドモード。他のスレッドがGTKのレンダリングを妨げる環境用
      $single_thread = true
    when '--skip-version-check' # あらゆるパッケージのバージョンチェックをしない
      $skip_version_check = true
    end
  }
end

argument_parser()

trace_var('$debug'){ require 'pp'; pp caller(); abort }

Dir.chdir(File.join(File.dirname($0), 'core'))

require File.expand_path('utils')
miquire :core, 'environment'
miquire :core, 'watch'
miquire :core, 'post'
miquire :mui, 'extension'
miquire :core, 'delayer'

seterrorlevel(:notice) if $debug

require 'benchmark'
require 'webrick' # require to daemon
require 'thread'
require 'fileutils'

Thread.abort_on_exception = true

def boot()
  logfile(Environment::LOGDIR)
  #if(already_exists_another_instance?) then
  #  error('Already exist another instance')
  #  exit!
  #end
  include File::Constants
  if $daemon then
    WEBrick::Daemon.start{
      main()
    }
  else
    main()
  end
  return true
end

def create_pidfile()
  begin
    open(Environment::PIDFILE, WRONLY|CREAT|EXCL){ |output|
      output.write(Process.pid)
    }
  rescue Errno::EEXIST
    error('to write pid file failed.')
    exit
  end
end

def already_exists_another_instance?
  if FileTest.exist? Environment::PIDFILE then
    open(Environment::PIDFILE){|out|
      pid = out.read
      if pid_exist?(pid) then
        notice "process #{pid} already exist"
        return true
      else
        File::delete(Environment::PIDFILE)
        notice "pid file exist. however, process #{pid} not found"
        return false
      end
    }
    error 'pid file can\'t open'
    exit
  else
    notice 'pid file not found'
  end
  return false
end

def main()
  #create_pidfile
  notice Environment::VERSION

  require File.expand_path './plugin'
  Miquire::Plugin.loadpath << 'plugin' << 'addon' << '../plugin' << '~/.mikutter/plugin'
  Miquire::Plugin.each{ |path| require path }

  watch = Watch.instance

  if($interactive) then
    loop{
      print '> '
      input = STDIN.gets.chomp
      case (input)
      when 'q'
        exit
      when 'help'
        puts 'exit: "q"'
      else
        watch.action(Message.new(input, :user => Hash[:id, 0, :idname, 'toshi_a']))
      end
    }
  else
    count = 600
    Gtk.timeout_add(100){
      Gtk::Lock.unlock
      if(count > 600) then
        notice 'run'
        watch.action
        count = 0
      end
      count += 1
      Delayer.run
      Gtk::Lock.lock
      true
    }
    Gtk::Lock.lock
    Gtk.main
  end
end

def gen_xml(msg)
  xml = REXML::Document.new open('chi_timeline_cachereplies')
  status = xml.root.get_elements('//statuses/status/').first
  status.get_elements('text').first.add_text(msg)
  return xml
end

def check_config_permission
  directories = [Environment::CONFROOT, Environment::LOGDIR, Environment::TMPDIR]
  directories.each{ |dir|
    FileUtils.mkdir_p(File.expand_path(dir)) }
  Dir.glob(directories.map{ |path| File.join(File.expand_path(path), '**', '*') }.join("\0")){ |file|
    unless FileTest.writable_real?(file)
      chi_fatal_alert("#{file} に書き込み権限を与えてください") end
    unless FileTest.readable_real?(file)
      chi_fatal_alert("#{file} に読み込み権限を与えてください") end
  }
end

check_config_permission

errfile = File.join(File.expand_path(Environment::TMPDIR), 'mikutter_dump')
if File.exist?(errfile)
  File.rename(errfile, File.expand_path(File.join(Environment::TMPDIR, 'mikutter_error')))
end

begin
  if not $debug
    $stderr = File.open(errfile, 'w')
    def $stderr.write(string)
      super(string)
      self.fsync rescue nil
    end
  end
  boot()
  File.delete(errfile) if File.exist?(errfile)
rescue Interrupt => e
  File.delete(errfile) if File.exist?(errfile)
  raise e
rescue Exception => e
  m = e.backtrace.first.match(/(.+?):(\d+)/)
  file_put_contents(File.join(File.expand_path(Environment::TMPDIR), 'crashed_file'), m[1])
  file_put_contents(File.join(File.expand_path(Environment::TMPDIR), 'crashed_line'), m[2])
  raise e
ensure
  # $stderr.close if errlog.closed?
end
