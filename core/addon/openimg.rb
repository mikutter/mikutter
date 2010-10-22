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

  def self.display(url)
    w = Gtk::Window.new.set_title("（読み込み中）")
    w.set_default_size(*@size).move(*@position)
    w.signal_connect(:destroy){ w.destroy }
    size = DEFAULT_SIZE
    Thread.new{ # !> method redefined; discarding old inspect
      url = url.value if url.is_a? Thread
      if not(url.respond_to?(:to_s))
        w.set_title("URLの取得に失敗")
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

  def self.get_imgsrc(dom, id)
    if dom
      m = eval('/<img[^>]+id="' + Regexp.escape(id) + '".*?>/').match(dom)
      if m
        m = /src=(["'])([^\1]+?)\1/.match(m[0])
        return m[2] if m end end
    warn 'img not found'
  end

  def self.imgurlresolver(url, dom_id)
    res = dom = nil
    begin
      res = Net::HTTP.get_response(URI.parse(url))
      if(res.is_a?(Net::HTTPResponse)) and (res.code == '200')
        get_imgsrc(res.body, dom_id)
      else
        warn "#{res.code} failed" end
    rescue Timeout::Error, StandardError => e
      warn e end end

  def self.addsupport(cond, dom_id)
    Gtk::IntelligentTextview.addopenway(cond ){ |url, cancel|
      Delayer.new(Delayer::NORMAL, Thread.new{ imgurlresolver(url, 'main_image') }){ |url| display(url) }
    }
  end

  addsupport(/^http:\/\/twitpic.com\/[a-zA-Z0-9]+/, 'photo-display')
  addsupport(/^http:\/\/yfrog.com\/[a-zA-Z0-9]+/, 'main_image')

  Gtk::IntelligentTextview.addopenway(/\.(png|jpg|gif)$/ ){ |url, cancel|
    Delayer.new{ display(url) }
  }

  if $0 == __FILE__
    w = Gtk::Window.new
    w.signal_connect(:destroy){ Gtk::main_quit }
    w.show_all
    url = 'http://yfrog.com/ndinsbj'
    Delayer.new(Delayer::NORMAL, Thread.new{ imgurlresolver(url, 'main_image') }){ |url| display(url) }
    Gtk.timeout_add(1000){
      Delayer.run
      true
    }
    Gtk::main
  end
end
