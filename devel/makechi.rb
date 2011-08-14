# -*- coding: utf-8 -*-

=begin rdoc
  Mikutterのプラグインをすべて削除した空のCHIを作成する
=end

require 'fileutils'

def get_config_data(name)
  case name
  when "NAME"
    "chi"
  when "ACRO"
    "chi"
  else
    CHIConfig.const_get(name) end end

BASE = File.expand_path(File.dirname($0))
SRC = File.expand_path(File.join(File.dirname($0), '..'))
DEST = File.expand_path(File.join(File.dirname($0), 'src'))

Dir.chdir(BASE)

if FileTest.exist?(DEST)
  FileUtils.rm_rf DEST
  puts "directory #{DEST} already exist."
end

FileUtils.mkdir_p File.join(DEST, 'plugin')
FileUtils.cp File.join(SRC, 'mikutter.rb'), DEST
FileUtils.cp_r File.join(SRC, 'core'), DEST
FileUtils.rm_rf File.join(DEST, 'core', 'plugin', 'gui.rb')
FileUtils.rm_rf Dir.glob(File.join(DEST, 'core', 'addon', '*'))
FileUtils.cp_r Dir.glob(File.join(BASE, 'chiskel', '*')), DEST

Dir.chdir(File.join(DEST, 'core'))
require 'config'
Dir.chdir(BASE)

open(File.join(DEST, "core/config.rb"), 'w'){ |out|
  out.write([ '# -*- coding: utf-8 -*-','','module CHIConfig',
              CHIConfig.constants.map{ |name|
                value = get_config_data(name)
                value.gsub!('mikutter', 'chi') if value.is_a? String
                "  #{name} = #{value.inspect}"
              },
              'end'].join("\n")) }
