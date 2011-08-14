#
# 起動時間プラグイン
#

# システムの起動・終了などをTweetする

require File.expand_path(File.join(File.dirname(__FILE__),'..', 'utils'))
miquire :plugin, 'plugin'
miquire :core, 'environment'

class Plugin::Ping
  include ConfigLoader
  MAX_CHECK_INTERVAL = 64
  CONFIGFILE = "#{Environment::CONFROOT}ping"

  def initialize
    @config = FileTest.exist?(CONFIGFILE) ? confload(CONFIGFILE) : {}
    @checkinterval = Hash.new
    plugin = Plugin::create(:ping)
    plugin.add_event(:period, &method(:onperiod))
  end

  def onperiod(watch)
    @config.map{|node|
      Thread.new(node){ |host|
        nextcheck = checkinterval(host)[:next]
        if(nextcheck > 0) then
          notice "ping: #{host['host']} checks about #{nextcheck} minutes after"
          checkinterval(host)[:next] -= 1
          Thread.exit
        end
        hostname = host['host']
        if(hostname && system(sprintf(host['command'] || 'ping -c 1 -i 1 %s', hostname) + ' > /dev/null')) then
          notice "ping: #{hostname} living"
          check_success(host)
          if(at(hostname)) then
            store(hostname, false)
            if(host['find']) then
              watch.post(:message => host['find'])
            end
          end
        else
          notice "ping: #{hostname}: no route to host"
          check_fail(host)
          store("#{hostname}-nextcheck", 1)
          unless(at(hostname)) then
            store(hostname, true)
            if(host['lost']) then
              watch.post(:message => host['lost'])
            end
          end
        end
      }
    }.each{|thread| thread.join }
  end

  def check_success(host)
    wait = checkinterval(host)[:success] += 1
    checkinterval(host)[:next] = [wait << 2, MAX_CHECK_INTERVAL].min
  end

  def check_fail(host)
    wait = checkinterval(host)[:success] = 0
    checkinterval(host)[:next] = 0
  end

  def checkinterval(host)
    if not(@checkinterval[host['host'].to_s]) then
      @checkinterval[host['host'].to_s] = {:next => 0, :success => 0}
    end
    return @checkinterval[host['host'].to_s]
  end
end

if(command_exist?('ping')) then
  Plugin::Ping.new
end
