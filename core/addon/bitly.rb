
miquire :core, 'messageconverters'
miquire :addon, 'addon'
miquire :addon, 'settings'
miquire :core, 'userconfig'

class Bitly < MessageConverters
  def user
    if UserConfig[:bitly_user] == '' or not UserConfig[:bitly_user]
      'mikutter'
    else
      UserConfig[:bitly_user]
    end end

  def apikey
    if UserConfig[:bitly_apikey] == '' or not UserConfig[:bitly_apikey]
      'R_70170ccac1099f3ae1818af3fa7bb311'
    else
      UserConfig[:bitly_apikey]
    end end

  def shrinked_url?(url)
    Regexp.new('http://(bit\\.ly|j\\.mp)/') === url end

  def shrink_url(urls)
    query = "version=2.0.1&login=#{user}&apiKey=#{apikey}&" + urls.map{ |url|
      "longUrl=#{Escape.uri_segment(url).to_s}" }.join('&')
    3.times{
      result = JSON.parse(Net::HTTP.get("api.bit.ly", "/shorten?#{query}"))
      return Hash[ *result['results'].map{|pair| [pair[0], pair[1]['shortUrl']] }.flatten ] if result
      sleep(1) }
    nil
  end end

module Addon
  class Bitly < Addon
    include SettingUtils

    def onboot(watch)
      Plugin::Ring::fire(:plugincall, [:settings, watch, :regist_tab, self.main(watch), 'bit.ly'])
    end

    def main(watch)
      box = Gtk::VBox.new(false, 8)
      user, = gen_input('ユーザ名', :bitly_user)
      apikey, = gen_input('API Key', :bitly_apikey)
      ft = gen_group('アカウント設定',
                     user,
                     apikey,
                     Gtk::Label.new('パスワードじゃなくて、API Keyを入れてくださいね'))
      box.closeup(ft)
      return box
    end

  end
end

Plugin::Ring.push Addon::Bitly.new,[:boot]
