# -*- coding: utf-8 -*-
#! /usr/bin/ruby

require 'utils'
require 'environment'
require 'watch'
require 'post'
require 'webrick' # require to daemon

def boot()
  logfile(Environment::TMPDIR + Environment::ACRO)
  argument_parser()
  Service.new(true)
  if(already_exists_another_instance?) then
    error('Already exist another instance')
    exit!
  end
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

def argument_parser()
  $debug = false
  $learnable = true
  $daemon = false
  $interactive = false
  $quiet = false

  ARGV.each{ |arg|
    case arg
    when '-i' # インタラクティブモード(default:off)
      $interactive = true
    when '--debug' # デバッグモード(default:off)
      $debug = true
      seterrorlevel(:notice)
    when '-d' # デーモンモード(default:off)
      $daemon = true
    when '-l' # タグを学習しない(default:する)
      $learnable = false
    when '-q'
      $quiet = true
    end
  }
end

def main()
  create_pidfile
  notice Environment::VERSION

  if $debug then
    notice '-- ロードされたプラグイン一覧'
    Plugin::Ring.avail_plugins.each_pair{|name, insts|
      inst = insts.map{|inst| inst.class }.join(', ')
      notice "#{name}: #{inst}"
    }
    notice '--'
  end

  watch = Watch.instance

  if($interactive) then
    loop{
      print '> '
      input = STDIN.gets.chomp
      case (input)
      when 'q'
        exit
      when 'help'
        puts '"q" とタイプすると終了します'
      else
        watch.action(Message.new(input, :user => Hash[:id, 0, :idname, 'toshi_a']))
      end
    }
  else
    loop{
      watch.action
      sleep 60
    }
  end
end

def gen_xml(msg)
  xml = REXML::Document.new open('chi_timeline_cachereplies')
  status = xml.root.get_elements('//statuses/status/').first
  status.get_elements('text').first.add_text(msg)
  return xml
end

begin
  boot()
rescue => err
  error("#{err.class} #{err.message}")
  err.backtrace.each{ |e| error e }
  error("fatal error. abort")
end

