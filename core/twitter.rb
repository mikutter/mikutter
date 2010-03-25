#
# Twitter Model Class
#

miquire :core, 'twitter_api'
miquire :core, 'message'

require "rexml/document"
require_if_exist 'httpclient'

class Twitter < TwitterAPI
  PROG_NAME = Environment::NAME

  def update(message)
    data = 'status=' + self.encode(message)
    data += '&in_reply_to_user_id=' + message.receiver[:id].to_s if message.receiver
    data += '&in_reply_to_status_id=' + message.receive_message[:id].to_s if message.receive_message
    data += '&source=' + self.encode(PROG_NAME)
    post_with_auth('/statuses/update.'+FORMAT, data, 'Host' => HOST)
  end

  def imageuploadable?
    defined?(HTTPClient)
  end

  def uploadimage(img)
    if not(self.imageuploadable?) then
      notice 'twitter: HTTPClient is not installed. failed to image upload'
      return nil
    end
    self.lock()
    result = nil
    boundary = 'mikuHa2ne'
    twitpic = HTTPClient.new
    notice 'twitter: twitpic uploading image'
    res = twitpic.post_content('http://twitpic.com/api/upload',
                               {:username => @user, :password => @pass, :media => img},
                               'content-type' => 'multipart/form-data, boundary='+boundary)
    notice 'twitter: twitpic response: '+res.inspect
    xml = REXML::Document.new(res)
    if(xml.root.attributes['stat'] == 'ok') then
      result = xml.root.get_elements('//rsp/').first.get_text('mediaurl').value
      notice 'twitter: twitpic upload success. url: '+result
    else
      warn 'twitter: twitpic upload failed.'
    end
    self.unlock()
    return result
  end

  def getimage(img)
    if(not img.url) and (img.resource) then
      img.url = self.uploadimage(img.resource)
      if(img.url == nil) then
        errimg = '/tmp/' + Time.now.strftime(Environment.ACRO+'-errorimage-%Y%m%d-%H%M%S')
        FileUtils.copy(img.path, errimg)
        warn "twitter: twitpic error image copied to #{errimg}"
      end
    end
    return img.url
  end

  def encode(message)
    return URI.encode(message.to_s, /[^a-zA-Z0-9\'\.\-\*\(\)\_]/n)
  end

end
