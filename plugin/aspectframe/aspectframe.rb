# -*- coding: utf-8 -*-
require 'fileutils'

=begin
このファイルを見た人へ
このことを絶対誰にも言わないでください

どうしても言いたい人は、毎年4/1(JST)の間だけはいいですよ

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
    Plugin::AspectFrame.now
  end

  if Plugin::AspectFrame::PREFETCH.cover?(now)
    FileUtils.mkdir_p(Plugin::AspectFrame::CACHE_DIR)
    # prefetch
    on_gui_timeline_add_messages do |_tl, messages|
      if Plugin::AspectFrame::PREFETCH.cover?(now)
        messages.deach do |message|
          if rand(1000) < now.day**2
            Plugin.call(:image_file_cache_photo, transform(message.user.icon))
          end
        end
      end
    end
  end
  if FileTest.exist?(Plugin::AspectFrame::CACHE_DIR) and not (Plugin::AspectFrame::PREFETCH.first..Plugin::AspectFrame::THE_DAY.last).cover?(now)
    notice 'destroy all prefetch data'
    FileUtils.rm_rf(Plugin::AspectFrame::CACHE_DIR) end

  # return fetched data
  filter_image_cache do |url, image, &stop|
    if /https:\/\/mikutter\.hachune\.net\/img\/api\/([0-9A-F]{2})\.png/ =~ url
      local = localfile_hash($1)
      if FileTest.exist? local
        raw = file_get_contents(local)
        if raw and not raw.empty?
          stop.call([url, raw]) end end end
    [url, image] end

  filter_miracle_icon_filter do |photo|
    if enable_sequence? :true_mikutter
      [transform(photo)]
    else
      [photo] end end

  filter_main_icon_form do |form|
    if enable_sequence? :germany_bird
      [:aspectframe]
    else
      [form] end end

  def transform(icon)
    if icon.perma_link
      Plugin.collect(:photo_filter, "https://mikutter.hachune.net/img/api/#{Digest::MD5.hexdigest(icon.perma_link.to_s)[0,2].upcase}.png", Pluggaloid::COLLECT).first
    else
      icon
    end
  end

  def localfile_hash(hash)
    File.expand_path(File.join(Plugin::AspectFrame::CACHE_DIR, "#{hash.upcase}_5.png")) end

  def the_day?
    Plugin::AspectFrame::THE_DAY.cover?(now) end

  def enable_sequence
    Plugin::AspectFrame::SCHEDULE.lazy.select{|s| s.range.cover? now} end

  def enable_sequence?(seq)
    enable_sequence.map(&:slug).include? seq end

end
