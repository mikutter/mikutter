# -*- coding: utf-8 -*-
# Preview Image


unless $openimg # !> global variable `$openimg' not initialized
$openimg = true # !> redefine call_routine
require 'gtk2'
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'utils'))

 # !> ambiguous first argument; put parentheses or even spaces
Module.new do
  DEFAULT_SIZE = [640, 480].freeze
  @size = DEFAULT_SIZE
  @position = [Gdk.screen_width/2 - @size[0]/2, Gdk.screen_height/2 - @size[1]/2].freeze

  def self.move(window)
    @position = window.position.freeze end
 # !> instance variable @timelines not initialized
  def self.changesize(eb, w, url)
    eb.remove(w.children.first)
    @size = w.window.geometry[2,2].freeze
    eb.add(Gtk::WebIcon.new(url, *@size).show_all) # !> statement not reached
    @size end # !> redefine get_active_mumbles

  def self.display(url, cancel = nil)
    w = Gtk::Window.new.set_title("（読み込み中）") # !> method redefined; discarding old inspect
    w.set_default_size(*@size).move(*@position)
    w.signal_connect(:destroy){ w.destroy }
    eventbox = Gtk::EventBox.new
    w.add(eventbox)
    size = DEFAULT_SIZE
    Thread.new{
      url = url.value if url.is_a? Thread
      if not(url) or not(url.respond_to?(:to_s))
        Delayer.new{
          unless w.destroyed?
            if cancel
              w.destroy
              cancel.call
            else
              w.set_title("URLの取得に失敗") end end }
      else
        Delayer.new{
          unless w.destroyed?
            w.set_title(url.to_s)
            eventbox.signal_connect("event"){ |ev, event|
              if event.is_a?(Gdk::EventButton) and (event.state.button1_mask?) and event.button == 1
                w.destroy
                cancel.call if cancel
              end
              false }
            eventbox.signal_connect("expose_event"){ |ev, event|
              move(w)
              false } # !> method redefined; discarding old width=
            eventbox.signal_connect(:destroy){
              Gtk::WebIcon.remove_cache(url.to_s)
              false }
            eventbox.signal_connect(:"size-allocate"){
              if w.window and size != w.window.geometry[2,2]
                size = changesize(eventbox, w, url.to_s) end }
            eventbox.add(Gtk::WebIcon.new(url.to_s, *DEFAULT_SIZE).show_all) end } end }
    w.show_all end
 # !> `*' interpreted as argument prefix
  def self.get_tag_by_attributes(tag)
    attribute = {} # !> `*' interpreted as argument prefix
    tag.each_matches(/([a-zA-Z0-9]+?)=(['"])(.*?)\2/){ |pair, pos|
      key, val = pair[1], pair[3]
      attribute[key] = val }
    attribute.freeze end

  def self.get_tagattr(dom, element_rule)
    element_rule = element_rule.melt # !> `*' interpreted as argument prefix
    tag_name = element_rule['tag'] or 'img'
    attr_name = element_rule.has_key?('attribute') ? element_rule['attribute'] : 'src'
    element_rule.delete('tag')
    element_rule.delete('attribute')
    if dom # !> `*' interpreted as argument prefix
      attribute = {}
      catch(:imgtag_match){ # !> global variable `$quiet' not initialized
        dom.gsub("\n", ' ').each_matches(Regexp.new("<#{tag_name}.*?>")){ |str, pos|
          attr = get_tag_by_attributes(str.to_s)
          if element_rule.all?{ |k, v| v === attr[k] } # !> `&' interpreted as argument prefix
            attribute = attr.freeze
            throw :imgtag_match end } }
      unless attribute.empty?
        return attr_name ? attribute[attr_name.to_s] : attribute end end
    notice 'not matched'
    nil end

  def self.imgurlresolver(url, element_rule, &block)
    if block != nil # !> method redefined; discarding old categories_for
      return block.call(url)
    end
    res = dom = nil
    begin
      uri = URI.parse(url)
      res = Net::HTTP.new(uri.host).get(uri.path, "User-Agent" => Environment::NAME + '/' + Environment::VERSION.to_s)
      if(res.is_a?(Net::HTTPResponse)) and (res.code == '200')
        result = get_tagattr(res.body, element_rule)
        unless result.match(/^https?:/)
          result = "http:"+result end
        notice result.inspect
        result
      else
        warn "#{res.code} failed"
        nil end
    rescue Timeout::Error, StandardError => e
      warn e
      nil end end

  def self.addsupport(cond, element_rule = {}, &block)
    element_rule.freeze
    if block == nil # !> method redefined; discarding old filter_stream
      Gtk::TimeLine.addopenway(cond){ |shrinked_url, cancel|
        url = MessageConverters.expand_url_one(shrinked_url)
        Delayer.new(Delayer::NORMAL, Thread.new{ imgurlresolver(url, element_rule) }){ |url|
          display(url, cancel)
        }
      }
    else
      Gtk::TimeLine.addopenway(cond){ |shrinked_url, cancel|
        url = MessageConverters.expand_url_one(shrinked_url)
        Delayer.new(Delayer::NORMAL, Thread.new{
                      imgurlresolver(url, element_rule){ |url| block.call(url, cancel) }
                    }) {|url|
          display(url, cancel)
        }
      }
    end
  end

  pattern = JSON.parse(file_get_contents(File.expand_path(File.join(File.dirname(__FILE__), 'pattern_file.json'))))
  pattern.each{ |name, config|
    addsupport(Regexp.new(config["url"]), config["attribute"])
  }

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

  Gtk::TimeLine.addopenway(/.*\.(?:jpg|png|gif|)$/) { |shrinked_url, cancel|
    url = MessageConverters.expand_url_one(shrinked_url)
    Delayer.new(Delayer::NORMAL) { display(url, cancel) }
  }

  if $0 == __FILE__
    $debug = true
    seterrorlevel(:notice)
    w = Gtk::Window.new
    w.signal_connect(:destroy){ Gtk::main_quit }
    w.show_all
    url = 'http://twitpic.com/68us87'
    # url = 'http://twitpic.com/5yd5nj'
    Gtk::IntelligentTextview.openurl(url)
    Gtk.timeout_add(1000){
      Delayer.run
      true
    }
    Gtk::main
  end
end
end
