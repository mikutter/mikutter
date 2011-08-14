#
# Temperature
#

require File.expand_path(File.join(File.dirname(__FILE__),'..', 'utils'))
miquire :lib, 'sensor'
miquire :lib, 'graph'

if(command_exist?('sensors'))
  Module.new do
    CONFIGFILE = "#{Environment::CONFROOT}temperature"

    def self.boot
      @store = ConfigLoader.create("Plugin::Temperature")
      @sensor = Sensor.new
      getconfig
      graph_reset end

    def self.getconfig
      config = FileTest.exist? (CONFIGFILE) ? confload(CONFIGFILE) : {}
      @identity = config.fetch(:identity, 'C')
      @critical = config.fetch(:critical, 70)
      @max_temp = config.fetch(:max_temp, 100)
      @interval = config.fetch(:interval, 60 * 24) end

    plugin = Plugin::create(:ping)
    plugin.add_event(:period){ |service|
      temps = @sensor.sensor
      graph_temp = temps.dup
      @sensor.hddtemp.each{ |temp|
        graph_temp[temp[:path]] = temp[:temp] }
      self.graph_add(graph_temp, service)
      temp = @sensor.cputemp(temps)
      if temp
        if is_critical?(temp)
          return service.post(:message => "#{temp}#{@identity}なう。熱いです・・・。",
                            :tags => [:tempreture, :critical]) end
        if counter = @store.at(:counter, 0)
          @store.store(:counter, counter.abs - 1) end end }

    def self.is_critical?(temp)
      limit = @store.at(:critical_limit, 0)
      if (temp >= (limit + @critical)) then
        @store.store(:critical_limit, @max_temp - @critical)
        return true
      elsif (limit != 0)
        @store.store(:critical_limit, limit.abs - 1) end
      return false end

    def self.samples(temp)
      samp = @store.at(:samp, [])
      samp.unshift(temp)
      @store.store(:samp, samp[0..@interval])
      return samp[1..@interval+1] end

    def self.graph_add(temps, watch)
      notice temps.inspect
      temps.each{|key, stat|
        if(not @cputemp[key].is_a?(Array)) then
          @cputemp[key] = Array.new
        end
        @cputemp[key][@temp_count] = stat.to_f
      }
      @count_label.call(nil)
      @temp_count += 1
      if(@temp_count >= @interval) then
        watch.post(Graph.drawgraph(@cputemp,
                                   :start => @start_time,
                                   :title => 'Temperature',
                                   :tags => ['temperature'],
                                   :label => @count_label,
                                   :end => Time.now)){ |e, m|
          Delayer.new{ raise m } if e == :fail
        }
        self.graph_reset
      end
      notice "temperature: next graph upload: #{@interval-@temp_count} minutes after"
    end

    def self.graph_reset
      @count_label = Graph.gen_graph_label_defer()
      @temp_count = 0
      @cputemp = Hash.new
      @start_time = Time.now
    end

    boot
  end
end
