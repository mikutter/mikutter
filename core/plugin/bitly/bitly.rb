# -*- coding: utf-8 -*-

class Bitly < MessageConverters
  USER = 'mikutter'
  APIKEY = 'R_70170ccac1099f3ae1818af3fa7bb311'

  def initialize
    # bit.lyの一度のリクエストでexpandできる最大数は15
    # http://code.google.com/p/bitly-api/wiki/ApiDocumentation#/v3/expand
    @expand_queue = TimeLimitedQueue.new(15, 0.1, Set){ |set|
      Thread.new{
        begin
          expanded_urls = expand_url_many(set)
          if expanded_urls.is_a? Enumerable
            expanded_urls.each{ |pair|
              shrinked, expanded = pair
              ew_proc = @expand_waiting[shrinked]
              if ew_proc.respond_to? :call
                atomic{
                  ew_proc.call(expanded)
                  @expand_waiting.delete(shrinked) } end } end
        rescue Exception => e
          set.to_a.each{ |url|
            ew_proc = @expand_waiting[shrinked]
            if ew_proc.respond_to? :call
              atomic {
                ew_proc.call(url)
                @expand_waiting.delete(url) } end } end } }
    @expand_waiting = Hash.new        # { url => Proc(url) }
  end

  def plugin_name
    :bitly
  end

  # bitlyユーザ名を返す
  def user
    if UserConfig[:bitly_user] == '' or not UserConfig[:bitly_user]
      USER
    else
      UserConfig[:bitly_user]
    end end

  # bitly API keyを返す
  def apikey
    if UserConfig[:bitly_apikey] == '' or not UserConfig[:bitly_apikey]
      APIKEY
    else
      UserConfig[:bitly_apikey]
    end end

  # 引数urlがこのプラグインで短縮されているものならtrueを返す
  def shrinked_url?(url)
    url.is_a? String and Regexp.new('^http://(bit\\.ly|j\\.mp)/') === url end

  # urlの配列 urls を受け取り、それら全てを短縮して返す
  def shrink_url(url)
    query = "login=#{user}&apiKey=#{apikey}&longUrl=#{Escape.query_segment(url).to_s}"
    3.times{
      response = begin
                   JSON.parse(Net::HTTP.get("api.bit.ly", "/v3/shorten?#{query}"))
                 rescue Exception
                   nil end
      if response and response['status_code'].to_i == 200
        return response['data']['url'] end
      sleep(1) }
    nil end

  # 短縮されたURL url を受け取り、それら全てを展開して返す。
  def expand_url(url)
    return nil unless shrinked_url? url
    url.freeze
    stopper = Queue.new
    atomic{
      if(@expand_waiting[url])
        parent = @expand_waiting[url]
        @expand_waiting[url] = lambda{ |url| parent.call(url); stopper << url }
      else
        @expand_waiting[url] = lambda{ |url| stopper << url }
      end
      @expand_queue.push(url) }
    timeout(5){ stopper.pop }
  rescue Exception => e
    error e
    url end

  def expand_url_many(urls)
    notice urls
    urls = urls.select &method(:shrinked_url?)
    return nil if urls.empty?
    query = "login=#{user}&apiKey=#{apikey}&" + urls.map{ |url|
      "shortUrl=#{Escape.query_segment(url).to_s}" }.join('&')
    3.times{
      result = begin
                 JSON.parse(Net::HTTP.get("api.bit.ly", "/v3/expand?#{query}"))
               rescue Exception
                 nil end
      if result and result['status_code'].to_i == 200
        return Hash[ *result['data']['expand'].map{|token|
                       [token['short_url'], token['long_url']] }.flatten ] end
      sleep(1) }
    nil end

  regist

end

Module.new do
  USER = 'mikutter'
  APIKEY = 'R_70170ccac1099f3ae1818af3fa7bb311'
  NAVIGATION = <<EOM
設定しなくたって使えるけれど、設定するとbitlyのページからクリックされた回数とかわかるようになるよ。
Bit.lyにログインし、 http://bit.ly/a/your_api_key にアクセスすると表示されるbit.ly API key を、下のボタンをクリックして「APIキー」に入力して下さい。
EOM


  def self.boot
    plugin = Plugin::create(:bitly)
    plugin.add_event(:boot){ |service|
      Plugin.call(:regist_url_shrinker_setting, 'bit.ly', main(service)) }
  end

  def self.main(watch)
    ft = Mtk.accountdialog_button('bit.ly アカウント設定',
                                  :bitly_user, 'ユーザ名',
                                  :bitly_apikey, 'APIキー'){ |user, pass|
      if(pass == '' and user == '')
        true
      else
        query = "/v3/validate?x_login=#{user}&x_apiKey=#{pass}&apiKey=#{APIKEY}"+
          "&login=#{USER}&format=json"
        begin
          result = JSON.parse(Net::HTTP.get("api.bit.ly", query))
          notice result.inspect
          result['data']['valid'].to_i == 1
        rescue JSON::ParserError
          nil end end }
    Gtk::VBox.new(false, 8).closeup(Gtk::IntelligentTextview.new(NAVIGATION)).closeup(ft) end

  boot
end

# Plugin::Ring.push Addon::Bitly.new,[:boot]
