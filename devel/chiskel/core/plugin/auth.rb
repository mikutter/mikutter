#
# Auth
# ログイン履歴をつぶやくプラグイン
#

require File.expand_path(File.join(File.dirname(__FILE__),'..', 'utils'))
miquire :plugin, 'plugin'
miquire :core, 'autotag'

Module.new do
  AuthDebugMode = false

  reg_sshlogin = /Accepted ([^\s]+) for ([^\s]+) from ([^\s]+) port ([^\s]+) (ssh[^\s]+)/
  localip = /^(10|127|192|169\.254|172\.(1[6-9]|2\d|30|31))\./
  size = 0
  @movable = lazy{ FileTest.readable_real?(auth_log_file) }
  logsize = lazy{ if (@movable && !AuthDebugMode) then FileTest.size(auth_log_file) else 0 end }

  plugin = Plugin::create(:auth)
  plugin.add_event(:period){ |service|
    if (log_avail? and has_newlog?) then
      log_read { |log|
        parse = reg_sshlogin.match(log)
        if parse then
          notice "auth: log receive '#{log.chomp}' > match"
          vals = parse.to_a
          vals[0] = log
          Hash[*[:log, :auth, :user, :host, :port, :protocol].zip(vals).flatten]
        else
          notice "auth: log receive '#{log.chomp}' > not match"
          nil
        end
      }.compact.each{ |log|
        if(log[:user] == "root") then
          if(localip === log[:host]) then
            # for root login by local
            return service.post(:message => "#{log[:host]}からrootでのログインを確認。",
                                :tags => [:auth,:warn])
          else
            # for root login by remote
            return service.post(:message => "#{log[:host]}からrootでのログインを確認。",
                                :tags => [:auth, :critical])
          end
        elsif(log[:auth] == "password" && !(localip === log[:host])) then
          # for password login by remote
          return service.post(:message => "#{log[:host]}からユーザ#{log[:user]}でパスワードでのログインを確認。グローバルからは公開鍵のほうがいいと思う。",
                              :tags => [:auth, :warn])
        elsif(log[:auth] == "password") then
          # for password login by local
          return service.post(:message => "#{log[:host]}からユーザ#{log[:user]}でパスワードでのログインを確認。",
                              :tags => [:auth, :notice])
        elsif(!(localip === log[:host])) then
          # for not password login by remote
          return service.post(:message => "#{log[:host]}からユーザ#{log[:user]}でのログインを確認。",
                              :tags => [:auth, :notice]) end } end }

  # 監視を実行すべきかどうかを判定する。
  # もし、一度ログを削除されていたら、@logsizeを0に設定する
  def self.log_avail?()
    if (@movable and FileTest.exist?(auth_log_file)) then
      true
    else
      logsize = 0
      false end end

  # 新しいログがあるようであれば真を返す
  def self.has_newlog?()
    logsize = FileTest.size(auth_log_file)
    logsize > logsize end

  def self.log_read(offset=logsize)
    logsize = FileTest.size(auth_log_file)
    notice "auth: read file #{auth_log_file} from #{offset} bytes"
    IO.read(logfile, nil, offset).map{ |r| yield(r) } end

  def self.auth_log_file()
    if(AuthDebugMode)
      'auth.log'
    else
      '/var/log/auth.log' end end end
