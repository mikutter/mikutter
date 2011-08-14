# /usr/bin/ruby

require "socket"

class Sensor
  def initialize()
    @busy = nil
    @all = nil
  end

  def sensor()
    IO.popen('sensors', 'r') do |input|
      result = Hash.new
      input.each{ |temp|
        key, value = temp.split(':')
        if(value != nil and key =~ /Core|temp/) then
          result[key] = value.trim_n
        end
      }
      hddtemp().each{ |temp|
        if(temp[:temp] =~ /^-?[0-9]+(\.[0-9]+)?$/) then
          result[temp[:path]] = temp[:temp].to_f
        end
      }
      notice result.inspect
      return result
    end
    error 'sensorsの起動に失敗: lm_sensorはインストールされていますか？'
    return false
  end

  def cputemp(temps = nil)
    temps = self.sensor unless temps
    temps['Core 0'] or temps['temp1']
  end

  def hddtemp()
    begin
      s_temp = TCPSocket.open("localhost", 7634)
      raw = s_temp.read
      s_temp.close
      keys = [:path, :device, :temp, :identity]
      raw.split('||').map{|node| Hash[*keys.zip(node.split('|').select{|r| !r.empty? }).flatten]}
    rescue Errno::ECONNREFUSED
      []
    end
  end

  def cpulate()
    open('/proc/stat', 'r') do |psh|
      if(psh.readline =~ /^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/) then
        user = $1.to_i; nice = $2.to_i; sys = $3.to_i; idle = $4.to_i
        lastall = @all
        lastbusy = @busy
        @all = (@busy = user + nice + sys) + idle
        if lastall then
          return (lastbusy - @busy) * 100 / (lastall - @all)
        end
      end
    end
  end

end
