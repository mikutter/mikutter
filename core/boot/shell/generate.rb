# -*- coding: utf-8 -*-
# プラグイン自動生成

require "fileutils"

slug = ARGV[1]

unless slug
  puts "plugin_slug not specified."
  puts "usage: mikutter.rb #{ARGV[0]} plugin_slug"
  exit
end

plugin_path = File.expand_path(File.join(CHIConfig::CONFROOT, "plugin", slug))
FileUtils.mkdir_p(plugin_path)
puts "directory generated: #{plugin_path}"
File.open("#{plugin_path}/#{slug}.rb", "w"){ |io|
  io.write <<"EOM";
# -*- coding: utf-8 -*-

Plugin.create(:#{slug}) do

end
EOM
}
puts "file generated: #{plugin_path}/#{slug}.rb"
