# -*- coding: utf-8 -*-
# Preview Image

require 'gtk2'
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'utils'))

miquire :mui, 'webicon'
miquire :mui, 'intelligent_textview'
miquire :core, 'delayer'

Module.new do
  DEFAULT_SIZE = [640, 480].freeze # !> `*' interpreted as argument prefix
  @size = DEFAULT_SIZE
  @position = [Gdk.screen_width/2 - @size[0]/2, Gdk.screen_height/2 - @size[1]/2].freeze

  def self.move(window)
    @position = window.position.freeze end

  def self.changesize(w, url)
    w.remove(w.children.first)
    @size = w.window.geometry[2,2].freeze
    w.add(Gtk::WebIcon.new(url, *@size).show_all)
    @size end

  def self.display(url, cancel = nil)
    w = Gtk::Window.new.set_title("（読み込み中）")
    w.set_default_size(*@size).move(*@position)
    w.signal_connect(:destroy){ w.destroy }
    size = DEFAULT_SIZE
    Thread.new{ # !> method redefined; discarding old inspect
      url = url.value if url.is_a? Thread
      if not(url.respond_to?(:to_s))
        Delayer.new{
          if cancel
            w.destroy
            cancel.call
          else
            w.set_title("URLの取得に失敗") end }
      else
        Delayer.new{
          w.set_title(url.to_s)
          w.signal_connect("expose_event"){ |w, event|
            move(w)
            false }
          w.signal_connect(:"size-allocate"){
            if w.window and size != w.window.geometry[2,2]
              size = changesize(w, url.to_s) end }
          w.add(Gtk::WebIcon.new(url.to_s, *DEFAULT_SIZE).show_all) } end }
    w.show_all end

  def self.get_tag_by_attributes(tag)
    attribute = {}
    tag.each_matches(/([a-zA-Z0-9]+?)=(['"])(.*?)\2/){ |pair, pos|
      key, val = pair[1], pair[3]
      attribute[key] = val }
    attribute.freeze end

  def self.get_imgsrc(dom, element_rule)
    if dom
      attribute = {}
      catch(:imgtag_match){
        dom.each_matches(/<img.*?>/){ |str, pos|
          attr = get_tag_by_attributes(str.to_s)
          if element_rule.all?{ |k, v| v === attr[k] }
            attribute = attr.freeze
            throw :imgtag_match end } }
      unless attribute.empty?
        return attribute['src'] end end
    warn "<img> not found '/<img[^>]+id=\"#{Regexp.escape(id)}\".*?>/'"
    nil end

  def self.imgurlresolver(url, element_rule)
    res = dom = nil
    begin
      res = Net::HTTP.get_response(URI.parse(url))
      if(res.is_a?(Net::HTTPResponse)) and (res.code == '200')
        get_imgsrc(res.body, element_rule)
      else
        warn "#{res.code} failed"
        nil end
    rescue Timeout::Error, StandardError => e
      warn e
      nil end end

  def self.addsupport(cond, element_rule)
    element_rule.freeze
    Gtk::IntelligentTextview.addopenway(cond ){ |url, cancel|
      Delayer.new(Delayer::NORMAL, Thread.new{ imgurlresolver(url, element_rule) }){ |url|
        display(url, cancel) } } end

  # Twitpic
  addsupport(/^http:\/\/twitpic\.com\/[a-zA-Z0-9]+/, 'id' => 'photo-display')

  # yfrog
  addsupport(/^http:\/\/yfrog\.com\/[a-zA-Z0-9]+/, 'id' => 'main_image')

  # Twipple Photo
  addsupport(/^http:\/\/p\.twipple\.jp\/[a-zA-Z0-9]+/, 'id' => 'post_image')

  # 携帯百景
  addsupport(/^http:\/\/movapic\.com\/[a-zA-Z0-9]+\/pic\/\d+/, 'class' => 'image', 'src' => /^http:\/\/image\.movapic\.com\/pic\//)

  # plixi (うごかん)
  # addsupport(/^http:\/\/plixi\.com\/p\/\d+/, 'id' => 'photo')

  Gtk::IntelligentTextview.addopenway(/\.(png|jpg|gif)$/ ){ |url, cancel|
    Delayer.new{ display(url, cancel) }
  }

  if $0 == __FILE__
    w = Gtk::Window.new
    w.signal_connect(:destroy){ Gtk::main_quit }
    w.show_all
    url = 'http://movapic.com/oriori/pic/1714939'
    Delayer.new(Delayer::NORMAL, Thread.new{ imgurlresolver(url, 'class' => 'image', 'src' => /^http:\/\/image\.movapic\.com\/pic\// ) }){ |url|
      display(url) }
    Gtk.timeout_add(1000){
      Delayer.run
      true
    }
    Gtk::main
  end
end
