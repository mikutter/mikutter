# -*- coding: utf-8 -*-
# 設定ファイルなどの権限チェック

miquire :core, 'environment'

begin
  directories = [Environment::CONFROOT, Environment::LOGDIR, Environment::TMPDIR]
  directories.each{ |dir|
    FileUtils.mkdir_p(File.expand_path(dir)) }
  Dir.glob(directories.map{ |path| File.join(File.expand_path(path), '**', '*') }.join("\0")){ |file|
    unless FileTest.writable_real?(file)
      chi_fatal_alert("#{file} に書き込み権限を与えてください") end
    unless FileTest.readable_real?(file)
      chi_fatal_alert("#{file} に読み込み権限を与えてください") end
  }
end
