#!/usr/bin/env ruby
#-*- coding: utf-8 -*-

#
# Ruby-PIAPRO v0.3
#

# Auth.authの第3引数に1を与えれば再度ログインする必要が多分無くなる
# 証明書はどうするべきか

require "kconv"
require "open-uri"
require "net/https"

class PIAPRO
  USER_AGENT   = "Ruby-PIAPRO/0.3"
  REFERER      = "http://piapro.jp/"
  MY_CHARCODE     = Kconv::UTF8
  PIAPRO_CHARCODE = Kconv::SJIS

  # CA_FILE      = "piapro.crt"

  module Auth
    LOGIN_PAGE = "https://piapro.jp/login/?mode=input"

    def self.auth(user, passwd, auto_login = nil)
      https = Net::HTTP.new("piapro.jp", 443)
      https.use_ssl      = true
      # https.ca_file      = CA_FILE
      # https.verify_mode  = OpenSSL::SSL::VERIFY_PEER
      # https.verify_depth = 5
      https.start {|session|
        post_login = Net::HTTP::Service.new("/login/")
        post_login["User-Agent"] = USER_AGENT
        post_login["Referer"]    = REFERER
        post_login.set_form_data(
                                 {
                                   :mode           => "exe",
                                   :login_url      => LOGIN_PAGE,
                                   :login_email    => user,
                                   :login_password => passwd,
                                   :auto_login     => auto_login # 1 is Auto Login ON,
                                 }
                                 )
        response = session.request(post_login)
        @cookie  = response["Set-Cookie"]
      }
      return @cookie
    end

    def self.logout(cookie)
      open("http://piapro.jp/logout/?mode=exe",
           "User-Agent" => USER_AGENT,
           "Cookie"     => @cookie,
           "Referer"    => REFERER
           ){|f|
        return f.read
      }
    end
  end


  class Download
    def initialize(arg={})
      if arg[:cookie]
        @cookie = arg[:cookie]
      elsif arg[:user] and arg[:passwd]
        @cookie = PIAPRO::Auth.auth(arg[:user], arg[:passwd])
      end
    end

    # urlからダウンロード
    # コンテンツページurl、短縮urlはNG。直接ダウンロードリンク指定が必要
    def download_url(url, filename=nil)
      open(url,
           "User-Agent" => USER_AGENT,
           "Cookie"     => @cookie,
           "Referer"    => REFERER
           ){|f|
        return false unless f.meta["content-disposition"]
        ct_dp = Kconv.kconv(f.meta["content-disposition"], MY_CHARCODE, Kconv::AUTO)
        if ct_dp =~ /filename=\"(.+)\"/
          file_orgname = $1
        else
          return false
        end

        filename = file_orgname unless filename
        File.open(filename, "wb"){|new|
          new.write f.read
        }
        return filename
      }
    end

    
    # cidからダウンロード
    # typeにコンテンツのタイプ(audio、imageなど)を指定する
    def download(cid, type=nil, filename=nil)
      # http://piapro.jp/download/?view=content_image&id=cidcidcidcidcid
      url = "http://piapro.jp/download/" + "?"
      if type
        url << "view=content_#{type}&"
      else
        url << "view=content_audio&"
      end
      url << "id=#{cid}"

      open(url,
           "User-Agent" => USER_AGENT,
           "Cookie"     => @cookie,
           "Referer"    => REFERER
           ){|f|
        # f.meta.keys.each{|key|
        #   printf("%10s : %10s\n", key, Kconv.kconv(f.meta[key], MY_CHARCODE, Kconv::AUTO))
        # }
        # p f.meta
        return false unless f.meta["content-disposition"]
        ct_dp = Kconv.kconv(f.meta["content-disposition"], MY_CHARCODE, Kconv::AUTO)
        if ct_dp =~ /filename=\"(.+)\"/
          file_orgname = $1
        else
          return false
        end

        filename = file_orgname unless filename
        File.open(filename, "wb"){|new|
          new.write f.read
        }
        return filename
      }
    end
  end

  module Search
    # 500x500にトリムされた画像をURLのページから探して
    # それっぽいのを集めて配列で返し、
    # 無かったら空の配列を返す、ものすごく適当なメソッド。
    # ログイン不要。
    def self.trim_image(url)
      list = Array.new
      open(url){|f|
        f.each_line{|line|
          if line =~ /background:url\((http:\/\/.+?\.piapro\.jp\/timg\/.+?_0500_0500\.(jpg|png|gif))\)/i
            list << $1
          end
        }
      }
      return list
    end


    # コンテンツのDL URLをurlで指定したページから探し配列で返し、
    # 無かったら空の配列を返す、これまたてきとうなメソッド。
    # ログイン不要。
    def self.contents(url)
      list = Array.new
      open(url){|f|
        f.each_line{|line|
          if line =~ /href="(http:\/\/piapro.jp\/download\/.+?)"/i
            list << $1
          end
        }
      }
      return list
    end
  end
end


# p PIAPRO::Search.contents("http://piapro.jp/content/fjcott0kh5i6i8cv")
# p PIAPRO::Search.trim_image("http://piapro.jp/content/fjcott0kh5i6i8cv")


# p = PIAPRO::Download.new(:user=>"miku", :passwd=>"Mi93kU3KumIKu")
# p.download_url("http://piapro.jp/download/?view=content_image&id=qxm9zbou0q4exbvu")


# cookie = PIAPRO::Auth.auth("miku", "Mi93kU3KumIKu", 1)
# dl = PIAPRO::Download.new(:cookie => cookie)
# dl.download_url("http://piapro.jp/download/?view=content_image&id=hkvd0bfc91cpbdgm")
# p PIAPRO::Auth.logout(cookie)

