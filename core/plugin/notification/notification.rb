# coding: utf-8

Plugin.create :notification do
  def main
    next_time = (Time.new + 86400).freeze
    Reserver.new(next_time){ main }
    open("http://mikutter.hachune.net/notification.json") do |io|
      JSON.parse(io.read, symbolize_names: true).sort_by{|n| n[:expire]}.reverse_each do |node|
        Plugin.call(:gui_window_rewindstatus, Plugin::GUI::Window.instance(:default), node[:text], [Time.iso8601(node[:expire]),next_time].min)
      end
    end
  end

  Delayer.new{ main }
end
