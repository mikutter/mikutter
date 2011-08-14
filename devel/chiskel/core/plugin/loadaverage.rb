#
# CPU Load
#

# Display Load Average as graph if support gruff

require File.expand_path(File.join(File.dirname(__FILE__),'..', 'utils'))
miquire :plugin, 'plugin'
miquire :lib, 'graph'

require 'tempfile'

if command_exist?('uptime')
  Module.new do

    def self.boot
      config = confload("#{Environment::CONFROOT}loadaverage")
      @interval = config.fetch(:interval, 60 * 24)
      reset()
    end

      plugin = Plugin::create(:ping)
      plugin.add_event(:period){ |service|
        mins = load_average
        @figure_la['1min'] << mins[0]
        @figure_la['5min'] << mins[1]
        @figure_la['15min'] << mins[2]
        @label.call(nil)
        p @lastcheck
        p @interval
        if((@lastcheck + (@interval*60)) < Time.now) then
          notice "loadaverage: figure tweet"
          service.post(Graph.drawgraph(@figure_la,
                                       :title => 'Load Average',
                                       :label => @label,
                                       :tags => ['loadaverage'],
                                       :start => @lastcheck,
                                       :end => Time.now))
          reset end
        notice "loadaverage: next graph upload: #{(@lastcheck + (@interval*60) - Time.now)/60} min after" }

    def self.reset
      @lastcheck = Time.now
      @figure_la = Hash['1min', [], '5min', [], '15min', []]
      @label = Graph.gen_graph_label_defer end

    def self.load_average
      open('| uptime'){ |uptime|
        if(/load averages?:\s*(\d+\.\d+)[^\d]+(\d+\.\d+)[^\d]+(\d+\.\d+)/ === uptime.read)
          return $1.to_f, $2.to_f, $3.to_f end } end

    boot
  end
end
