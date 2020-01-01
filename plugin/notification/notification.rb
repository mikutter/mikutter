# coding: utf-8

Plugin.create :notification do
  settings(_('お知らせ')) do
    boolean(_('ステータスバーにmikutterから配信されるお知らせを表示する'), :notification_enable)
      .tooltip(_('チェックすると、ステータスバーに表示することが特にない間、mikutterの最新情報を表示しておきます。この変更は再起動後に適用されます'))
  end

  def main
    return unless UserConfig[:notification_enable]
    next_time = (Time.new + 86400).freeze
    Delayer.new(delay: next_time, &method(:main))
    open('https://mikutter.hachune.net/notification.json') do |io|
      JSON.parse(io.read, symbolize_names: true).sort_by{|n| n[:expire]}.reverse_each do |node|
        Plugin.call(:gui_window_rewindstatus, Plugin::GUI::Window.instance(:default), node[:text], [Time.iso8601(node[:expire]),next_time].min)
      end
    end
  end

  Delayer.new(&method(:main))
end
