# -*- coding: utf-8 -*-
# 設定ファイルなどの権限チェック

require 'fileutils'
require 'environment'

begin
  directories = [Environment::CONFROOT, Environment::LOGDIR, Environment::TMPDIR, Environment::SETTINGDIR]
  directories.each{ |dir|
    FileUtils.mkdir_p(File.expand_path(dir)) }
  Dir.glob(directories.map{ |path| File.join(File.expand_path(path), '**', '*') }){ |file|
    unless FileTest.writable_real?(file)
      chi_fatal_alert("#{file} に書き込み権限を与えてください") end
    unless FileTest.readable_real?(file)
      chi_fatal_alert("#{file} に読み込み権限を与えてください") end
  }
end
