# -*- coding: utf-8 -*-

require 'gtk2'
require 'cairo'
require_relative 'window'
require_relative 'model/album'

module Plugin::Openimg
  ImageOpener = Struct.new(:name, :condition, :open)
end

Plugin.create :openimg do
  # 画像アップロードサービスの画像URLから実際の画像を得る。
  # サービスによってはリファラとかCookieで制御してる場合があるので、
  # "http://twitpic.com/d250g2" みたいなURLから直接画像の内容を返す。
  # String url 画像URL
  # String|nil 画像
  defevent :openimg_raw_image_from_display_url,
           prototype: [String, tcor(IO, nil)]

  # 画像アップロードサービスの画像URLから画像のPixbufを得る。
  defevent :openimg_pixbuf_from_display_url,
           prototype: [String, tcor(:pixbuf, nil), tcor(Thread, nil)]

  # 画像を取得できるURLの条件とその方法を配列で返す
  defevent :openimg_image_openers,
           prototype: [Array]

  # 画像を新しいウィンドウで開く
  defevent :openimg_open,
           priority: :ui_response,
           prototype: [String, Message]

  defdsl :defimageopener do |name, condition, &proc|
    opener = Plugin::Openimg::ImageOpener.new(name.freeze, condition, proc).freeze
    filter_openimg_image_openers do |openers|
      openers << opener
      [openers] end end

  defimageopener(_('画像直リンク'), /.*\.(?:jpg|png|gif|)\Z/i) do |display_url|
    begin
      open(display_url)
    rescue => _
      error _
      nil end end

  filter_openimg_pixbuf_from_display_url do |display_url, loader, thread|
    raw  = Plugin.filtering(:openimg_raw_image_from_display_url, display_url, nil).last
    if raw
      begin
        loader = Gdk::PixbufLoader.new
        thread = Thread.new do
          begin
            loop do
              Thread.pass
              partial = raw.readpartial(1024*HYDE)
              atomic{ loader.write partial }
            end
            nil
          rescue EOFError
            true
          ensure
            raw.close rescue nil
            loader.close rescue nil end end
        [display_url, loader, thread]
      rescue => _
        error _
        [display_url, loader, thread] end
    else
      [display_url, loader, thread] end end

  filter_openimg_raw_image_from_display_url do |display_url, content|
    unless content
      openers = Plugin.filtering(:openimg_image_openers, Set.new).first
      content = openers.lazy.select{ |opener|
        opener.condition === display_url
      }.map{ |opener|
        opener.open.(display_url)
      }.select(&ret_nth).take(1).force.first end
    [display_url, content] end

  on_openimg_open do |display_url|
    Plugin::Openimg::Window.new(display_url).start_loading.show_all
  end

  intent Plugin::Openimg::Album do |intent|
    Plugin.call(:openimg_open, intent.model.perma_link.to_s)
  end

  def addsupport(cond, element_rule = {}, &block); end

end
