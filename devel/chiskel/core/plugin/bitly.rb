# -*- coding: utf-8 -*-

require File.expand_path(File.join(File.dirname(__FILE__),'..', 'utils'))
miquire :core, 'messageconverters'
miquire :core, 'userconfig'

class Bitly < MessageConverters
  USER = 'mikutter'
  APIKEY = 'R_70170ccac1099f3ae1818af3fa7bb311'
  def user
    if UserConfig[:bitly_user] == '' or not UserConfig[:bitly_user]
      USER
    else
      UserConfig[:bitly_user]
    end end

  def apikey
    if UserConfig[:bitly_apikey] == '' or not UserConfig[:bitly_apikey]
      APIKEY
    else
      UserConfig[:bitly_apikey]
    end end

  def shrinked_url?(url)
    Regexp.new('http://(bit\\.ly|j\\.mp)/') === url end

  def shrink_url(urls)
    query = "version=2.0.1&login=#{user}&apiKey=#{apikey}&" + urls.map{ |url|
      "longUrl=#{Escape.query_segment(url).to_s}" }.join('&')
    3.times{
      result = begin
                 JSON.parse(Net::HTTP.get("api.bit.ly", "/shorten?#{query}"))
               rescue JSON::ParserError
                 nil
               end
      return Hash[ *result['results'].map{|pair| [pair[0], pair[1]['shortUrl']] }.flatten ] if result
      sleep(1) }
    nil end end
