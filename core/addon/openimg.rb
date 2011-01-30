# -*- coding: utf-8 -*-
# Preview Image

require 'gtk2'
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'utils'))

miquire :mui, 'webicon'
miquire :mui, 'intelligent_textview'
miquire :core, 'delayer'
miquire :core, 'userconfig'
miquire :lib, 'piapro'

Module.new do
  DEFAULT_SIZE = [640, 480].freeze # !> `*' interpreted as argument prefix
  @size = DEFAULT_SIZE
  @position = [Gdk.screen_width/2 - @size[0]/2, Gdk.screen_height/2 - @size[1]/2].freeze

  def self.move(window)
    @position = window.position.freeze end

  def self.changesize(eb, w, url)
    eb.remove(w.children.first)
    @size = w.window.geometry[2,2].freeze
    eb.add(Gtk::WebIcon.new(url, *@size).show_all)
    @size end

  def self.display(url, cancel = nil)
    w = Gtk::Window.new.set_title("（読み込み中）")
    w.set_default_size(*@size).move(*@position)
    w.signal_connect(:destroy){ w.destroy }
    eventbox = Gtk::EventBox.new
    w.add(eventbox)
    size = DEFAULT_SIZE
    Thread.new{ # !> method redefined; discarding old inspect
      url = url.value if url.is_a? Thread
      if not(url) or not(url.respond_to?(:to_s))
        Delayer.new{
          if cancel
            w.destroy
            cancel.call
          else
            w.set_title("URLの取得に失敗") end }
      else
        Delayer.new{
          w.set_title(url.to_s)
          eventbox.signal_connect("event"){ |ev, event|
            if event.is_a?(Gdk::EventButton) and (event.state.button1_mask?) and event.button == 1
              w.destroy
              cancel.call if cancel
            end
            false }
          eventbox.signal_connect("expose_event"){ |ev, event|
            move(w)
            false }
          eventbox.signal_connect(:"size-allocate"){
            if w.window and size != w.window.geometry[2,2]
              size = changesize(eventbox, w, url.to_s) end }
          eventbox.add(Gtk::WebIcon.new(url.to_s, *DEFAULT_SIZE).show_all) } end }
    w.show_all end

  def self.get_tag_by_attributes(tag)
    attribute = {}
    tag.each_matches(/([a-zA-Z0-9]+?)=(['"])(.*?)\2/){ |pair, pos|
      key, val = pair[1], pair[3]
      attribute[key] = val }
    attribute.freeze end

  def self.get_tagattr(dom, element_rule)
    element_rule = element_rule.melt
    tag_name = element_rule['tag'] or 'img'
    attr_name = element_rule.has_key?('attribute') ? element_rule['attribute'] : 'src'
    element_rule.delete('tag')
    element_rule.delete('attribute')
    if dom
      attribute = {}
      catch(:imgtag_match){
        dom.each_matches(Regexp.new("<#{tag_name}.*?>")){ |str, pos|
          attr = get_tag_by_attributes(str.to_s)
          if element_rule.all?{ |k, v| v === attr[k] }
            attribute = attr.freeze
            throw :imgtag_match end } }
      unless attribute.empty?
        return attr_name ? attribute[attr_name.to_s] : attribute end end
    nil end

  def self.imgurlresolver(url, element_rule, &block)
    if block != nil
      return block.call(url)
    end
    res = dom = nil
    begin
      uri = URI.parse(url)
      res = Net::HTTP.new(uri.host).get(uri.path, "User-Agent" => Environment::NAME + '/' + Environment::VERSION.to_s)
      if(res.is_a?(Net::HTTPResponse)) and (res.code == '200')
        result = get_tagattr(res.body, element_rule)
        notice result
        result
      else
        warn "#{res.code} failed"
        nil end
    rescue Timeout::Error, StandardError => e
      warn e
      nil end end

  def self.addsupport(cond, element_rule = {}, &block)
    element_rule.freeze
    if block == nil
      Gtk::IntelligentTextview.addopenway(cond ){ |url, cancel|
        Delayer.new(Delayer::NORMAL, Thread.new{ imgurlresolver(url, element_rule) }){ |url|
          display(url, cancel)
        }
      }
    else
      Gtk::IntelligentTextview.addopenway(cond ){ |url, cancel|
        Delayer.new(Delayer::NORMAL, Thread.new{
                      imgurlresolver(url, element_rule){ |url| block.call(url, cancel) }
                    }) {|url|
          display(url, cancel)
        }
      }
    end
  end

  # Twitpic
  addsupport(/^http:\/\/twitpic\.com\/[a-zA-Z0-9]+/, 'id' => 'photo-display')

  # yfrog
  addsupport(/^http:\/\/yfrog\.com\/[a-zA-Z0-9]+/, 'id' => 'main_image')

  # Twipple Photo
  addsupport(/^http:\/\/p\.twipple\.jp\/[a-zA-Z0-9]+/, 'id' => 'post_image')

  # Moby picture
  addsupport(Regexp.new("^http://moby.to/[a-zA-Z0-9]+"), 'id' => 'main_picture')

  # 携帯百景
  addsupport(/^http:\/\/movapic\.com\/[a-zA-Z0-9]+\/pic\/\d+/, 'class' => 'image', 'src' => /^http:\/\/image\.movapic\.com\/pic\//)
  addsupport(/^http:\/\/movapic\.com\/pic\/[a-zA-Z0-9]+/, 'class' => 'image', 'src' => /^http:\/\/image\.movapic\.com\/pic\//)

  # plixi 参考: http://groups.google.com/group/plixi/web/fetch-photos-from-url
  addsupport(/^http:\/\/plixi\.com\/p\/\d+/, 'id' => 'photo') { |url, cancel|
    addr = "http://api.plixi.com/api/tpapi.svc/imagefromurl?size=medium&url=" + url
    response = Net::HTTP.get_response(URI.parse(addr))
    if response.is_a?(Net::HTTPRedirection)
      response['location']
    else
      warn "plixi url failed"
      nil
    end
  }

  # piapro
  piaproaccount = piaprocookie = nil
  addsupport(/^http:\/\/piapro.jp\/content\/[a-zA-Z0-9]+/){ |url, cancel|
    if piaproaccount != [UserConfig[:piapro_username], UserConfig[:piapro_password]]
      piaproaccount = [UserConfig[:piapro_username], UserConfig[:piapro_password]]
      piaprocookie = lazy{ PIAPRO::Auth.auth(UserConfig[:piapro_username], UserConfig[:piapro_password], 1) } end
    url = imgurlresolver(url, 'tag' => 'a', 'attribute' => 'href',
                         'href' => Regexp.new("^" + Regexp.escape("http://piapro.jp/download/?view=content_image&id=") + "[a-zA-Z0-9]+"))
    if url
      PIAPRO::Download.new(:cookie => piaprocookie).download_url(url, Gtk::WebIcon.get_filename(url))
    end }

  Gtk::IntelligentTextview.addopenway(/\.(png|jpg|gif)$/ ){ |url, cancel|
    Delayer.new{ display(url, cancel) }
  }

  Plugin::create(:openimg).add_event(:boot){ |service|
    container = Gtk::VBox.new(false, 8).
    closeup(Mtk.accountdialog_button('piapro アカウント設定',
                                  :piapro_username, 'ユーザ名',
                                  :piapro_password, 'パスワード'){ |user, pass|
              true })
    Plugin.call(:setting_tab_regist, container, '画像プレビュー') }

  if $0 == __FILE__
    $debug = true
    seterrorlevel(:notice)
    w = Gtk::Window.new
    w.signal_connect(:destroy){ Gtk::main_quit }
    w.show_all
    url = 'http://piapro.jp/content/h7e1cgpq3nujg93g'
    Gtk::IntelligentTextview.openurl(url)
    Gtk.timeout_add(1000){
      Delayer.run
      true
    }
    Gtk::main
  end
end
