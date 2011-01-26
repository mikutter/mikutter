# -*- coding: utf-8 -*-
#
# Twitter Model Class
#

miquire :core, 'twitter_api'
miquire :core, 'message'
miquire :core, 'messageconverters'

require "rexml/document"
require_if_exist 'rubygems'
require_if_exist 'httpclient'

class Twitter < TwitterAPI
  PROG_NAME = Environment::NAME

  def update(message)
    text = self.convert_message(message)
    return nil if not text
    replyto = message[:replyto]
    receiver = message[:receiver] or get_receiver(message)
    data = {:status => text }
    data[:in_reply_to_user_id] = User.generate(receiver)[:id].to_s if receiver
    data[:in_reply_to_status_id] = Message.generate(replyto)[:id].to_s if replyto
    post_with_auth('/statuses/update.'+FORMAT, data)
  end

  def send_direct_message(message)
    text = self.convert_message(message)
    post_with_auth('/direct_messages/new.' + FORMAT,
                   :text => text,
                   :user => User.generate(message[:user])[:id].to_s ) end

  def imageuploadable?
    defined?(HTTPClient)
  end

  def uploadimage(img, message)
    if not(self.imageuploadable?) then
      notice 'twitter: HTTPClient is not installed. failed to image upload'
      return nil end
    result = nil
    twitpic = HTTPClient.new
    notice 'twitter: twitpic uploading image'
    verify_credentials = "https://api.twitter.com/1/account/verify_credentials.json"
    ac_token = access_token
    request = ac_token.get_request(:get, verify_credentials)
    auth = request['Authorization']
    res = twitpic.post_content('http://api.twitpic.com/2/upload.json',
                               { :key => '030381b5b137acbb428c3661eb797d4e',
                                 :message => message,
                                 :media => img},
                               { 'X-Auth-Service-Provider' => verify_credentials,
                                 "X-Verify-Credentials-Authorization" => auth + ", realm=\"http://api.twitter.com/\""})
    notice 'twitter: twitpic response: '+res.inspect
    json = JSON.parse(res)
    if json
      result = json['url']
      if result
        notice 'twitter: twitpic upload success. url: '+result
        result
      else
        warn 'twitter: twitpic upload failed.' end end end

  def getimage(message)
    img = message[:image]
    if(not img.url) and (img.resource)
      img.url = self.uploadimage(img.resource, message[:message])
      if(img.url == nil)
        errimg = '/tmp/' + Time.now.strftime(Environment::ACRO+'-errorimage-%Y%m%d-%H%M%S')
        FileUtils.copy(img.path, errimg)
        warn "twitter: twitpic error image copied to #{errimg}" end end
    img.url end

  def convert_message(message)
    result = [message[:message]]
    if message[:tags].is_a?(Array)
      tags = message[:tags].select{|i| not message[:message].include?(i.to_s) }.map{|i| "##{i}"}
      notice tags.inspect
      result.concat(tags) if tags end
    receiver = get_receiver(message)
    if receiver and not(message[:message].include?("@#{receiver[:idname]}"))
      result = ["@#{receiver[:idname]}", *result] end
    if message[:image]
      image = getimage(message)
      if image
        result << image
      else
        return nil end end
    if message[:retweet]
      result << "RT" << "@#{message[:retweet][:user][:idname]}:" << message[:retweet].to_s
    end
    text = result.join(' ')
    if(UserConfig[:shrinkurl_always] or text.strsize > 140)
      text = MessageConverters.shrink_url_all(text) end
    text.shrink(140, URI.regexp(['http','https'])) if text end

  def get_receiver(message)
    if message[:receiver] then
      User.generate(message[:receiver])
    elsif(/@([a-zA-Z0-9_]+)/ === message[:message]) then
      User.findbyidname($1)
    elsif message[:replyto]
      message[:replyto][:user] rescue nil
    end
  end
end

module OAuth

  class AccessToken < ConsumerToken
    def get_request(http_method, path, *arguments)
      request_uri = URI.parse(path)
      site_uri = consumer.uri
      is_service_uri_different = (request_uri.absolute? && request_uri != site_uri)
      consumer.uri(request_uri) if is_service_uri_different
      response = super(http_method, path, *arguments)
      # NOTE: reset for wholesomeness? meaning that we admit only AccessToken service calls may use different URIs?
      # so reset in case consumer is still used for other token-management tasks subsequently?
      # consumer.uri(site_uri) if is_service_uri_different
      response
    end
  end

  class ConsumerToken < Token
    def get_request(http_method, path, *arguments)
      consumer.get_request(http_method, path, self, {}, *arguments)
    end
  end

  class Consumer
    def get_request(http_method, path, token = nil, request_options = {}, *arguments)
      if path !~ /^\//
        @http = create_http(path)
        _uri = URI.parse(path)
        path = "#{_uri.path}#{_uri.query ? "?#{_uri.query}" : ""}" end
      create_signed_request(http_method, path, token, request_options, *arguments) end
  end
end
