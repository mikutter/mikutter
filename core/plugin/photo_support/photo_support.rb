# coding: utf-8
require 'nokogiri'
require 'httpclient'

module Plugin::PhotoSupport
  INSTAGRAM_PATTERN = %r{^https?://(?:instagr\.am|instagram\.com)/p/([a-zA-Z0-9_\-]+)}
end

Plugin.create :photo_support do
  # twitpic
  defimageopener('twitpic', %r<^http://twitpic\.com/[a-zA-Z0-9]+>) do |display_url|
    connection = HTTPClient.new
    page = connection.get_content(display_url)
    next nil if page.empty?
    doc = Nokogiri::HTML(page)
    result = doc.css('img').lazy.find_all{ |dom|
      %r<https?://.*?\.cloudfront\.net/photos/(?:large|full)/.*> =~ dom.attribute('src')
    }.first
    open(result.attribute('src'))
  end

  # twipple photo
  defimageopener('twipple photo', %r<^http://p\.twipple\.jp/[a-zA-Z0-9]+>) do |display_url|
    connection = HTTPClient.new
    page = connection.get_content(display_url)
    next nil if page.empty?
    doc = Nokogiri::HTML(page)
    result = doc.css('#post_image').first
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
  defimageopener('gyazo', %r<^http://gyazo.com/[a-zA-Z0-9]+>) do |display_url|
    connection = HTTPClient.new
    page = connection.get_content(display_url)
    next nil if page.empty?
    doc = Nokogiri::HTML(page)
    result = doc.css('#gyazo_img').first
    open(result.attribute('src'))
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
    dom = doc.css('#_image').first
    notice dom.attribute('style')
    result = if /background:[^;]*?url\(([^\)]+)\)/ =~ dom.attribute('style')
               $1 end
    open(result) if result
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

  # twitgoo
  defimageopener('twitgoo', %r<^http://twitgoo\.com/[a-zA-Z0-9]+>) do |display_url|
    open(display_url)
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
  defimageopener('imgur', %r<http://imgur\.com(/gallery)?/\w+>) do |display_url|
    connection = HTTPClient.new
    page = connection.get_content(display_url)
    next nil if page.empty?
    doc = Nokogiri::HTML(page)
    result = doc.css('img').lazy.find_all{ |dom|
      'image_src' == dom.attribute('rel')
    }.first
    open(result.attribute('href'))
  end

  # Fotolog
  defimageopener('Fotolog', %r<http://(?:www\.)fotolog\.com/\w+/\d+/?>) do |display_url|
    connection = HTTPClient.new
    page = connection.get_content(display_url)
    next nil if page.empty?
    doc = Nokogiri::HTML(page)
    result = doc.css('meta').lazy.find_all{ |dom|
      'og:image' == dom.attribute('property').to_s
    }.first
    open(result.attribute('content'))
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
    m = display_url.match(Plugin::PhotoSupport::INSTAGRAM_PATTERN)
    shortcode = m[1]
    open("https://instagram.com/p/#{shortcode}/media/?size=l")
  end

  # d250g2
  defimageopener('d250g2', %r#\Ahttp://d250g2.com/?\Z#) do
    open('http://d250g2.com/d250g2.jpg')
  end

  # d250g2(Twitpicが消えたとき用)
  defimageopener('d250g2(Twitpicが消えたとき用)', %r#\Ahttp://twitpic.com/d250g2\Z#) do
    open('http://d250g2.com/d250g2.jpg')
  end

  # totori.dip.jp
  defimageopener('totori.dip.jp', %r#\Ahttp://totori.dip.jp/?\Z#) do |display_url|
    connection = HTTPClient.new
    page = connection.get_content(display_url)
    next nil if page.empty?
    doc = Nokogiri::HTML(page)
    open(doc.css('meta[property="og:image"]').first.attribute('content'))
  end

  # 600eur.gochiusa.net
  defimageopener('600eur.gochiusa.net', %r#\Ahttp://600eur\.gochiusa\.net/?\Z#) do |display_url|
    connection = HTTPClient.new
    page = connection.get_content(display_url)
    next nil if page.empty?
    doc = Nokogiri::HTML(page)
    open(doc.css('meta[name="twitter:image:src"]').first.attribute('content'))
  end
end
