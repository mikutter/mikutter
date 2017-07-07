# -*- coding: utf-8 -*-
require_relative 'model/web'

Plugin.create(:web) do
  extend Memoist

  intent Plugin::Web::Web, label: _('外部ブラウザで開く') do |intent_token|
    openurl(intent_token.model.perma_link.to_s)
  end

  def openurl(url)
    if UserConfig[:url_open_specified_command]
      url_open_command = UserConfig[:url_open_command]
      bg_system(url_open_command, url)
    elsif(defined? Win32API) then
      shellExecuteA = Win32API.new('shell32.dll','ShellExecuteA',%w(p p p p p i),'i')
      shellExecuteA.call(0, 'open', url, 0, 0, 1)
    else
      url_open_command = find_url_open_command
      if url_open_command
        bg_system(url_open_command, url)
      else
        activity :system, _("この環境で、URLを開くためのコマンドが判別できませんでした。設定の「表示→URLを開く方法」で、URLを開く方法を設定してください。") end end
  rescue => exception
    title = _('コマンド "%{command}" でURLを開こうとしましたが、開けませんでした。設定の「表示→URLを開く方法」で、URLを開く方法を設定してください。') % {command: url_open_command}
    description = {
      title: title,
      message: exception.to_s,
      backtrace: exception.backtrace.join("\n") }
    activity :system, title,
             error: exception,
             description: "%{title}\n\n%{message}\n\n%{backtrace}" % description
  end

  # URLを開くことができるコマンドを返す。
  memoize def find_url_open_command
    openable_commands = %w{xdg-open open /etc/alternatives/x-www-browser}
    wellknown_browsers = %w{firefox chromium opera}
    command = nil
    catch(:urlopen) do
      openable_commands.each{ |o|
        if command_exist?(o)
          command = o
          throw :urlopen end }
      wellknown_browsers.each{ |o|
        if command_exist?(o)
          activity :system, _('この環境で、URLを開くためのコマンドが判別できなかったので、"%{command}"を使用します。設定の「表示→URLを開く方法」で、URLを開く方法を設定してください。') % {command: command}
          command = o
          throw :urlopen end } end
    command end
end
