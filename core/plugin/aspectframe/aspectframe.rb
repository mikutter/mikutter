# -*- coding: utf-8 -*-
require 'fileutils'

=begin
このファイルを見た人へ
このことを絶対ツイートしないでください

どうしてもしたい人は、毎年4/1(JST)の間だけしてもいいですよ

としぁ
=end

module Plugin::AspectFrame
  def self.now
    Time.new end

  Sequence = Struct.new(:slug, :range) do
    def ===(other)
      case other
      when Sequence
        self == other
      when Symbol, String
        slug == other.to_sym
      when Time
        range.include? other end end end
  THE_DAY = Time.new(now.year, 4, 1)..Time.new(now.year, 4, 2)
  SequenceTrueMikutter = Sequence.new(:true_mikutter, THE_DAY.first..Time.new(now.year, 4, 1, 12))
  SequenceGermanyBird = Sequence.new(:germany_bird, Time.new(now.year, 4, 1, 12)..THE_DAY.last)
  SCHEDULE = [SequenceTrueMikutter, SequenceGermanyBird]
  PREFETCH = Time.new(now.year, 3, 1)..THE_DAY.first

  CACHE_DIR = File.expand_path(File.join(Environment::CACHE, "af"))
end

Plugin.create :aspectframe do

  def now
    Plugin::AspectFrame.now end

  if (Plugin::AspectFrame::PREFETCH.first..Plugin::AspectFrame::SequenceTrueMikutter.range.last).cover? now
    FileUtils.mkdir_p(Plugin::AspectFrame::CACHE_DIR)
    # prefetch
    onappear do |messages|
      if Plugin::AspectFrame::PREFETCH.cover?(now)
        messages.each { |message|
          if rand(1000) < Time.new.day**2 and not FileTest.exist?(localfile(message.user.icon.uri.to_s))
            Enumerator.new{|y|
              Plugin.filtering(:photo_filter, transform(message.user.icon.uri.to_s), y)
            }.first.download.next{ |photo|
              notice "prefetch: #{photo.uri}"
              SerialThread.new{
                File.open(localfile(photo.uri.to_s), 'w'){|out| out << photo.blob }
              }
            }.terminate end } end
    end
  end
  if FileTest.exist?(Plugin::AspectFrame::CACHE_DIR) and not (Plugin::AspectFrame::PREFETCH.first..Plugin::AspectFrame::THE_DAY.last).cover?(now)
    notice 'destroy all prefetch data'
    FileUtils.rm_rf(Plugin::AspectFrame::CACHE_DIR) end

  # return fetched data
  filter_image_cache do |url, image, &stop|
    if /http:\/\/toshia.dip.jp\/img\/api\/([0-9A-F]{2})\.png/ =~ url
      local = localfile_hash($1)
      if FileTest.exist? local
        raw = file_get_contents(local)
        if raw and not raw.empty?
          stop.call([url, raw]) end end end
    [url, image] end

  filter_web_image_loader_url_filter do |url|
    if enable_sequence? :true_mikutter
      [transform(url)]
    else
      [url] end end

  filter_main_icon_form do |form|
    if enable_sequence? :germany_bird
      [:aspectframe]
    else
      [form] end end

  def transform(url)
    "http://toshia.dip.jp/img/api/#{Digest::MD5.hexdigest(url)[0,2].upcase}.png"
  end

  def localfile(url)
    localfile_hash(Digest::MD5.hexdigest(url)[0,2]) end

  def localfile_hash(hash)
    File.expand_path(File.join(Plugin::AspectFrame::CACHE_DIR, "#{hash.upcase}_5.png")) end

  def the_day?
    Plugin::AspectFrame::THE_DAY.cover?(now) end

  def enable_sequence
    Plugin::AspectFrame::SCHEDULE.lazy.select{|s| s.range.cover? now} end

  def enable_sequence?(seq)
    enable_sequence.map(&:slug).include? seq end

end
