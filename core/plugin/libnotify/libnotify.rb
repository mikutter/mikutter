# -*- coding: utf-8 -*-
# notify-sendコマンド又はruby-libnotifyで通知を表示する。

if require_if_exist('RNotify') and defined?(Notify) and Notify.init("mikutter") # ruby-libnotifyがつかえる場合
  require File.expand_path File.join(File.dirname(__FILE__), 'rnotify')
elsif command_exist? 'notify-send' # notify-sendコマンドが有る場合
  require File.expand_path File.join(File.dirname(__FILE__), 'notify-send')
end
