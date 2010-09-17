require 'uri'

class MessageConverters
  @@ring = []

  def self.inherited(klass)
    self.append(klass.new) end

  def self.append(klass)
    @@ring = @@ring.push(klass) end

  def self.shrink_url_all(text)
    urls = text.matches(shrinkable_url_regexp)
    return text if(urls.empty?)
    table = self.shrink_url(urls)
    text.gsub(shrinkable_url_regexp){ |k| table[k] } if table end

  def self.expand_url_all(text)
    urls = text.matches(shrinkable_url_regexp)
    return text if(urls.empty?)
    table = self.expand_url(urls)
    text.gsub(shrinkable_url_regexp){ |k| table[k] } if table end

  def self.shrink_url(url)
    shrinked, redandancy = *url.partition{ |item|
      self.shrinked_url?(item) }
    if not redandancy.empty?
      @@ring.each{ |shrinker|
        r = shrinker.shrink_url(redandancy)
        return r.update(Hash[*shrinked.zip(shrinked)]) if r } end
    Hash[url.zip(url)] end

  def self.expand_url(url)
    shrinked, redandancy = *url.partition{ |item|
      self.shrinked_url?(item) }
    if not shrinked.empty?
      @@ring.each{ |expander|
        r = expander.expand_url(shrinked)
        return r.update(Hash[*redandancy.zip(redandancy)]) if r } end
    Hash[url.zip(url)] end

  def self.shrinkable_url_regexp
    URI.regexp(['http','https']) end

  def self.shrinked_url?(url)
    @@ring.any?{ |shrinker|
      shrinker.shrinked_url?(url) } end

  def shrink_url(url)
    nil end

  def expand_url(url)
    nil end

  def shrinked_url?(url)
    nil end

  # no override follow

  def shrink_url_ifnecessary(url)
    if shrinked_url?(url)
      url
    else
      shrink_url(url)
    end
  end
end
