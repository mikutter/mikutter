# graph
# draw graph

require_if_exist 'rubygems'
require_if_exist 'gruff'

module Graph
  def self.graph_drawable?
    return defined?(Gruff)
  end

  # values = {records=>[points(Numeric)]}
  # options = {
  #   :title => 'graph title'
  #   :tags => ['hash tags']
  #   :label => ['label of column']
  #   :start => 'label of start'
  #   :end => 'label of end'
  # }
  def self.drawgraph(values, options)
    notice 'graph: '+options.inspect
    if(self.graph_drawable?) then
      graph = Gruff::Line.new
      length = 0
      values.each{ |key, ary|
        graph.data(key, ary)
        length = [length, ary.size].max
      }
      if(options[:label].is_a? Proc) then
        label = options[:label].call(:get).freeze
      else
        label = (options[:label] || Hash.new).freeze
      end
      if (not options[:end]) then
        options[:end] = Time.now
      end
      notice 'graph: '+label.inspect
      graph.labels = label
      graph.title = options[:title] + '(' + options[:start].strftime('%Y/%m/%d') + ')'
      tmpfile = Tempfile.open('graph')
      tmpfile.write(graph.to_blob)
      result = {
        :message => "#{options[:start].strftime('%Y/%m/%d %H:%M')}から#{options[:end].strftime('%m/%d %H:%M')}の#{options[:title]}のグラフ",
        :tags => options[:tags],
        :image => Message::Image.new(tmpfile.path)}
      tmpfile.close
      result
    else
      table = values.values.flatten
      { :message => "#{options[:start].strftime('%Y/%m/%d %H:%M')}から#{options[:end].strftime('%m/%d %H:%M')}の#{options[:title]}は、最高#{table.max}、最低#{table.min}、平均#{table.avg.round_at(4)}です。",
        :tags => options[:tags]} end end

  # return graph label generator.
  def self.gen_graph_label_defer(default={0 => Time.now.strftime('%H')})
    last_sample_time = Time.now
    temp_label = default
    count = 0
    lambda{ |value|
      if(value == :get) then
        return temp_label
      elsif(value != nil) then
        temp_label[count] = value
      elsif(last_sample_time.strftime('%H') != Time.now.strftime('%H')) then
        temp_label[count] = Time.now.strftime('%H')
        last_sample_time = Time.now
      else
      end
      count += 1
      temp_label
    }
  end
end
