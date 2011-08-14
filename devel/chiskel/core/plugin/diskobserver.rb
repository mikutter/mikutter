#
# ディスク使用量プラグイン
#

# ディスク使用量が切迫していたらTweetする

require File.expand_path(File.join(File.dirname(__FILE__),'..', 'utils'))
miquire :lib, 'sensor'
require_if_exist 'rubygems'
require_if_exist 'sys/filesystem'

if defined? Sys::Filesystem
  Module.new do
    NR_statfs = 99
    MTAB = '/etc/mtab'

    @store = ConfigLoader.create("Plugin::DiskObserver")
    plugin = Plugin::create(:uptime)

    plugin.add_event(:period){ |service|
      if @store.at(:last_tweet, 0).to_i + 86400 > Time.new.to_i
        notice("diskobserver: next check time:" + Time.at(@store.at(:last_tweet, 0) + 86400).inspect)
      else
        r = detect
        if(r)
          service.post(r)
        else
          notice('diskobserver: no critical disks') end end }

    # 七割以上使われているパーティションを警告するメッセージを生成する
    def self.detect
      warnings = []
      observer_divide[7, 3].each_with_index {|v, i|
        warnings.push "#{v.join('と')}が#{i+7}割" if !v.empty? }
      if not warnings.empty?
        result = {:message => "#{warnings.join('、')}使われています。", :tags => [:diskobserver]}
        @store.store(:last_tweet, Time.now.to_i)
        return result end
      nil end

    # 各パーティションを使用されている容量10%ごとに配列に分ける
    def self.observer_divide
      disk_using = Array.new(10){ [] }
      Sys::Filesystem.mounts do |fs|
        stat = Sys::Filesystem.stat(fs.mount_point)
        if !['none','usbdevfs','proc','tmpfs'].include?(fs.mount_type) and stat.blocks_available != 0
          disk_using[(per_of_use(stat) * 10).to_i].push(fs.mount_point) end end
      disk_using end

    def self.per_of_use(stat)
      (stat.blocks - stat.blocks_available).to_f / stat.blocks end end
end
