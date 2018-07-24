# coding: utf-8
require 'nokogiri'
require 'httpclient'
require 'totoridipjp'

module Plugin::PhotoSupport
  INSTAGRAM_PATTERN = %r{\Ahttps?://(?:instagr\.am|(?:www\.)?instagram\.com)/p/([a-zA-Z0-9_\-]+)/}
  GITHUB_IMAGE_PATTERN = %r<\Ahttps://github\.com/(\w+/\w+)/blob/(.*\.(?:#{GdkPixbuf::Pixbuf.formats.flat_map do |f| f.extensions end.join '|'}))\z>

  class << self
    extend Memoist

    def via_xpath(display_url, xpath)
      connection = HTTPClient.new
      page = connection.get_content(display_url)
      unless page.empty?
        doc = Nokogiri::HTML(page)
        doc.xpath(xpath).first
      end
    end

    # Twitter cardsのURLを画像のURLに置き換える。
    # HTMLを頻繁にリクエストしないように、このメソッドを通すことでメモ化している。
    # ==== Args
    # [display_url] http://d250g2.com/
    # ==== Return
    # String 画像URL(http://d250g2.com/d250g2.jpg)
    def d250g2(display_url)
      r = via_xpath(display_url, "//meta[@name='twitter:image']/@content")
      return r if r
      via_xpath(display_url, "//meta[@name='twitter:image:src']/@content")
    end
    memoize :d250g2

    # OpenGraphProtocol対応のURLを画像のURLに置き換える。
    # HTMLを頻繁にリクエストしないように、このメソッドを通すことでメモ化している。
    # ==== Args
    # [display_url] https://www.instagram.com/p/Bj4XIgNHacT/
    # ==== Return
    # String 画像URL(https://scontent-nrt1-1.cdninstagram.com/vp/867c287aac67e555f873458042d25c70/5BC16C10/t51.2885-15/e35/33958857_788214964721700_3554146954256580608_n.jpg)
    def インスタ映え(display_url)
      via_xpath(display_url, "//meta[@property='og:image']/@content") end
    memoize :"インスタ映え"
  end
end

Plugin.create :photo_support do
  # twitpic
  defimageopener('twitpic', %r<^https?://twitpic\.com/[a-zA-Z0-9]+>) do |display_url|
    connection = HTTPClient.new
    connection.transparent_gzip_decompression = true
    page = connection.get_content(display_url)
    next nil if page.empty?
    doc = Nokogiri::HTML(page)
    result = doc.css('img').lazy.find_all{ |dom|
      %r<https?://.*?\.cloudfront\.net/photos/(?:large|full)/.*> =~ dom.attribute('src')
    }.first
    open(result.attribute('src'))
  end

  # moby picture
  defimageopener('moby picture', %r<^http://moby.to/[a-zA-Z0-9]+>) do |display_url|
    connection = HTTPClient.new
    page = connection.get_content(display_url)
    next nil if page.empty?
    doc = Nokogiri::HTML(page)
    result = doc.css('#main_picture').first
    open(result.attribute('src'))
  end

  # gyazo
  defimageopener('gyazo', %r<\Ahttps?://gyazo.com/[a-zA-Z0-9]+>) do |display_url|
    img = Plugin::PhotoSupport.d250g2(display_url)
    open(img) if img
  end

  # 携帯百景
  defimageopener('携帯百景', %r<^http://movapic.com/(?:[a-zA-Z0-9]+/pic/\d+|pic/[a-zA-Z0-9]+)>) do |display_url|
    connection = HTTPClient.new
    page = connection.get_content(display_url)
    next nil if page.empty?
    doc = Nokogiri::HTML(page)
    result = doc.css('.image').lazy.find_all{ |dom|
      %r<^http://image\.movapic\.com/pic/> =~ dom.attribute('src')
    }.first
    open(result.attribute('src'))
  end

  # piapro
  defimageopener('piapro', %r<^http://piapro.jp/t/[a-zA-Z0-9]+>) do |display_url|
    connection = HTTPClient.new
    page = connection.get_content(display_url)
    next nil if page.empty?
    doc = Nokogiri::HTML(page)
    dom = doc.css('.illust-whole img').first
    url = dom && dom.attribute('src')
    if url
      open(url) end
  end

  # img.ly
  defimageopener('img.ly', %r<^http://img\.ly/[a-zA-Z0-9_]+>) do |display_url|
    connection = HTTPClient.new
    page = connection.get_content(display_url)
    next nil if page.empty?
    doc = Nokogiri::HTML(page)
    result = doc.css('#the-image').first
    open(result.attribute('src'))
  end

  # jigokuno.com
  defimageopener('jigokuno.com', %r<^http://jigokuno\.com/\?eid=\d+>) do |display_url|
    connection = HTTPClient.new
    page = connection.get_content(display_url)
    next nil if page.empty?
    doc = Nokogiri::HTML(page)
    open(doc.css('img.pict').first.attribute('src'))
  end

  # はてなフォトライフ
  defimageopener('はてなフォトライフ', %r<^http://f\.hatena\.ne\.jp/[-\w]+/\d{9,}>) do |display_url|
    connection = HTTPClient.new
    page = connection.get_content(display_url)
    next nil if page.empty?
    doc = Nokogiri::HTML(page)
    result = doc.css('img.foto').first
    open(result.attribute('src'))
  end

  # imgur
  defimageopener('imgur', %r<\Ahttps?://imgur\.com(?:/gallery)?/[a-zA-Z0-9]+>) do |display_url|
    connection = HTTPClient.new
    page = connection.get_content(display_url)
    next nil if page.empty?
    doc = Nokogiri::HTML(page)
    result = doc.css('link[rel="image_src"]').first
    open(result.attribute('href').to_s)
  end

  # Fotolog
  defimageopener('Fotolog', %r<\Ahttps?://(?:www\.)?fotolog\.com/\w+/\d+/?>) do |display_url|
    img = Plugin::PhotoSupport.インスタ映え(display_url)
    open(img) if img
  end

  # フォト蔵
  defimageopener('フォト蔵', %r<^http://photozou\.jp/photo/show/\d+/\d+>) do |display_url|
    connection = HTTPClient.new
    page = connection.get_content(display_url)
    next nil if page.empty?
    doc = Nokogiri::HTML(page)
    open(doc.css('img[itemprop="image"]').first.attribute('src'))
  end

  # instagram
  defimageopener('instagram', Plugin::PhotoSupport::INSTAGRAM_PATTERN) do |display_url|
    img = Plugin::PhotoSupport.インスタ映え(display_url)
    open(img) if img
  end

  # d250g2
  defimageopener('d250g2', %r#\Ahttps?://(?:[\w\-]+\.)?d250g2\.com/?\Z#) do |display_url|
    img = Plugin::PhotoSupport.d250g2(display_url)
    open(img) if img
  end

  # d250g2(Twitpicが消えたとき用)
  defimageopener('d250g2(Twitpicが消えたとき用)', %r#\Ahttp://twitpic\.com/d250g2\Z#) do
    open('http://d250g2.com/d250g2.jpg')
  end

  # totori.dip.jp
  defimageopener('totori.dip.jp', %r#\Ahttp://totori\.dip\.jp/?\Z#) do |display_url|
    iwashi = Totoridipjp.イワシがいっぱいだあ…ちょっとだけもらっていこうかな
    if iwashi.url
      open(iwashi.url) end
  end

  # 600eur.gochiusa.net
  defimageopener('600eur.gochiusa.net', %r#\Ahttp://600eur\.gochiusa\.net/?\Z#) do |display_url|
    img = Plugin::PhotoSupport.d250g2(display_url)
    open(img) if img
  end

  # yfrog
  defimageopener('yfrog', %r#\Ahttps?://yfrog\.com/es3bcstj\Z#) do
    img = Plugin::PhotoSupport.d250g2('http://router-cake.d250g2.com/')
    open(img) if img
  end

  defimageopener('いらすとや', %r<https?://(?:www.)?irasutoya\.com/\d{4}/\d{2}/.+\.html>) do |display_url|
    img = Plugin::PhotoSupport.d250g2(display_url)
    open(img) if img
  end

  # vine
  defimageopener('vine', %r<\Ahttps?://vine\.co/v/[a-zA-Z0-9]+>) do |display_url|
    connection = HTTPClient.new
    page = connection.get_content(display_url)
    next nil if page.empty?
    doc = Nokogiri::HTML(page)
    result = doc.css('meta[property="twitter:image:src"]')
    open(result.attribute('content').value)
  end

  # xkcd.com
  defimageopener('xkcd', %r<\Ahttps?://xkcd\.com/[0-9]+>) do |display_url|
    connection = HTTPClient.new
    page = connection.get_content(display_url)
    next nil if page.empty?
    doc = Nokogiri::HTML(page)
    result = doc.css('#comic > img').first
    src = result.attribute('src').to_s
    if src.start_with?('//')
      src = Diva::URI.new(display_url).scheme + ':' + src
    end
    open(src)
  end

  # マシュマロ
  defimageopener('marshmallow-qa', %r<\Ahttps?://marshmallow-qa\.com/messages/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}>) do |display_url|
    img = Plugin::PhotoSupport.インスタ映え(display_url)
    open(img) if img
  end

  # peing
  defimageopener('peing', %r<\Ahttps?://peing\.net/\w+/(?:qs/\d+|q/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})>) do |display_url|
    img = Plugin::PhotoSupport.d250g2(display_url)
    open(img) if img
  end

  # ニコニコ静画
  defimageopener('NicoSeiga', %r<\Ahttps?://seiga\.nicovideo\.jp/seiga/im\d+>) do |display_url|
    img = Plugin::PhotoSupport.インスタ映え(display_url)
    open(img) if img
  end

  # ニコニコ静画 (nico.ms経由)
  defimageopener('NicoSeiga via nico.ms', %r<\Ahttps?://nico\.ms/im\d+>) do |display_url|
    connection = HTTPClient.new
    location = connection.get(display_url).header['Location'].first
    next nil if location.nil?
    img = Plugin::PhotoSupport.インスタ映え(location)
    open(img) if img
  end

  # GitHub
  defimageopener('github', Plugin::PhotoSupport::GITHUB_IMAGE_PATTERN) do |display_url|
    url = Plugin::PhotoSupport::GITHUB_IMAGE_PATTERN.match(display_url) do |m|
      "https://raw.githubusercontent.com/#{m[1]}/#{m[2]}"
    end
    open(url) if url
  end
end
