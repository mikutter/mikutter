# -*- coding: utf-8 -*-
# Preview Image

require 'gtk2'

Plugin.create :openimg do
  DEFAULT_SIZE = [640, 480].freeze
  USER_AGENT = (Environment::NAME + '/' + Environment::VERSION.to_s).freeze
  @size = DEFAULT_SIZE
  @position = [Gdk.screen_width/2 - @size[0]/2, Gdk.screen_height/2 - @size[1]/2].freeze

  def move(window)
    @position = window.position.freeze end

  def changesize(eb, w, url)
    eb.remove(eb.children.first)
    @size = w.window.geometry[2,2].freeze
    eb.add(::Gtk::WebIcon.new(url, *@size).show_all)
    @size end

  def redraw(eb, pb)
    ew, eh = eb.window.geometry[2,2]
    return if(ew == 0 or eh == 0)
    pb = pb.dup
    pb = pb.scale(*Gdk::WebImageLoader.calc_fitclop(pb, Gdk::Rectangle.new(0, 0, ew, eh)))
    eb.window.draw_pixbuf(nil, pb, 0, 0, (ew - pb.width)/2, (eh - pb.height)/2, -1, -1, Gdk::RGB::DITHER_NORMAL, 0, 0) end

  def display(url, cancel = nil)
    w = ::Gtk::Window.new.set_title(_("（読み込み中）"))
    w.set_size_request(320, 240)
    w.set_default_size(*@size).move(*@position)
    w.signal_connect(:destroy){ w.destroy }
    eventbox = ::Gtk::EventBox.new
    w.add(eventbox)
    size = DEFAULT_SIZE
    Thread.new{
      url = url.value if url.is_a? Thread
      if not(url) or not(url.respond_to?(:to_s))
        Delayer.new(:ui_response).new{
          unless w.destroyed?
            if cancel
              w.destroy
              cancel.call
            else
              w.set_title(_("URLの取得に失敗")) end end }
      else
        pixbuf = Gdk::WebImageLoader.loading_pixbuf(*@size)
        raw = Gdk::WebImageLoader.get_raw_data(url){ |data|
          if not eventbox.destroyed?
            if data
              begin
                loader = Gdk::PixbufLoader.new
                loader.write data
                loader.close
                pixbuf = loader.pixbuf
              rescue => _
                pixbuf = Gdk::WebImageLoader.notfound_pixbuf(*@size) end
            else
              pixbuf = Gdk::WebImageLoader.notfound_pixbuf(*@size) end
            eventbox.queue_draw_area(0, 0, *eventbox.window.geometry[2,2]) end }
        if raw and raw != :wait
          loader = Gdk::PixbufLoader.new
          loader.write raw
          loader.close
          pixbuf = loader.pixbuf end
        Delayer.new(:ui_passive){
          unless w.destroyed?
            w.set_title(url.to_s)
            eventbox.signal_connect("event"){ |ev, event|
              if event.is_a?(Gdk::EventButton) and (event.state.button1_mask?) and event.button == 1
                w.destroy
                cancel.call if cancel
              end
              false }
            eventbox.signal_connect("expose_event"){ |ev, event|
              redraw(eventbox, pixbuf)
              move(w)
              true }
            eventbox.signal_connect(:"size-allocate"){
              if w.window and size != w.window.geometry[2,2]
                redraw(eventbox, pixbuf)
                size = w.window.geometry[2,2] end }
            redraw(eventbox, pixbuf)
            eventbox end } end }
    w.show_all end

  def get_tag_by_attributes(tag)
    attribute = {}
    tag.scan(/([^\s=]+)=(['"])(.*?)\2/){ |pair|
      key, val = pair[1], pair[3]
      attribute[key] = val }
    attribute.freeze end

  def get_tagattr(dom, element_rule)
    element_rule = element_rule.melt
    tag_name = element_rule['tag'] or 'img'
    attr_name = element_rule.has_key?('attribute') ? element_rule['attribute'] : 'src'
    element_rule.delete('tag')
    element_rule.delete('attribute')
    if dom
      attribute = {}
      catch(:imgtag_match){
        dom.gsub("\n", ' ').scan(Regexp.new("<#{tag_name}.*?>")){ |str|
          attr = get_tag_by_attributes(str.to_s)
          if element_rule.all?{ |k, v| v === attr[k] }
            attribute = attr.freeze
            throw :imgtag_match end } }
      unless attribute.empty?
        return attr_name ? attribute[attr_name.to_s] : attribute end end
    notice 'not matched'
    nil end

  def imgurlresolver(url, element_rule, limit=5, &block)
    return nil if limit <= 0
    return block.call(url) if block != nil
    res = nil
    begin
      uri = URI.parse(url)
      path = uri.path + (uri.query ? "?"+uri.query : "")
      res = Net::HTTP.new(uri.host).get(path, "User-Agent" => USER_AGENT)
      case(res)
      when Net::HTTPSuccess
        address = get_tagattr(res.body, element_rule)
        case address
        when /\Ahttps?:/
          # Complete URL
          result = address
        when /\A\/\//
          # No scheme
          result = "http:" + address
        when /\A\//
          # Absolute path
          result = uri.dup
          result.path = address
        else
          # Relative path
          result = uri.dup
          result.merge!(address)
        end
        notice result.inspect
        result.to_s
      when Net::HTTPRedirection
        return imgurlresolver(res['Location'], element_rule, limit - 1, &block)
      else
        warn "#{res.code} failed"
        nil end
    rescue Timeout::Error, StandardError => e
      warn e
      nil end end

  def addsupport(cond, element_rule = {}, &block)
    element_rule.freeze
    if block == nil
      ::Gtk::TimeLine.addopenway(cond){ |shrinked_url, cancel|
        url = MessageConverters.expand_url_one(shrinked_url)
        Delayer.new(:ui_response){
          display(Thread.new{
                    imgurlresolver(url, element_rule) }, cancel) } }
    else
      ::Gtk::TimeLine.addopenway(cond){ |shrinked_url, cancel|
        url = MessageConverters.expand_url_one(shrinked_url)
        Delayer.new(:ui_response) {
          display(Thread.new{
                    imgurlresolver(url, element_rule){ |image_url|
                      block.call(image_url, cancel) }
                  }, cancel) } } end end

  pattern = JSON.parse(file_get_contents(File.expand_path(File.join(File.dirname(__FILE__), 'pattern_file.json'))), create_additions: true)
  pattern.each{ |name, config|
    addsupport(Regexp.new(config["url"]), config["attribute"])
  }

  # plixi 参考: http://groups.google.com/group/plixi/web/fetch-photos-from-url
  addsupport(/\Ahttp:\/\/plixi\.com\/p\/\d+/, 'id' => 'photo') { |url, cancel|
    addr = "http://api.plixi.com/api/tpapi.svc/imagefromurl?size=medium&url=" + url
    response = Net::HTTP.get_response(URI.parse(addr))
    if response.is_a?(Net::HTTPRedirection)
      response['location']
    else
      warn "plixi url failed"
      nil
    end
  }
  
  # Tumblr image
  # http://tmblr.co/[-\w]+ http://tumblr.com/[[:36進数:]]+
  # http://{screen-name}.tumblr.com/post/\d+
  # 上記を展開し、記事タイプがphotoかphotosetなら /post/ を /image/ にすると
  # 単一画像ページが得られることを利用した画像展開
  addsupport(/\Ahttp:\/\/([-0-9a-z]+\.tumblr\.com\/post\/\d+|tmblr\.co\/[-\w]+$|tumblr\.com\/[0-9a-z]+\Z)/, nil) { |url, cancel|
    def fetch(t)
      req = URI.parse(t)
      res = Net::HTTP.new(req.host).request_head(req.path)
      case res
      when Net::HTTPSuccess
        t
      when Net::HTTPRedirection
        fetch(res['location'])
      else
        nil
      end
    end
    
    t = fetch(url)
    /\A(http:\/\/[^\/]+\/)post(\/\d+)/ =~ t
    if $~
      imgurlresolver($1 + "image" + $2, {'tag' => 'img', 'id' => 'content-image', 'attribute' => 'data-src'})
    else
      warn "たんぶらの記事ページじゃないっぽい"
      nil
    end
  }

  INSTAGRAM_PATTERN = %r{^http://(?:instagr\.am/p/([a-zA-Z0-9_]+)|instagram\.com/p/([a-zA-Z0-9_-]+))}
  addsupport(INSTAGRAM_PATTERN) do |url, cancel|
    m = url.match(INSTAGRAM_PATTERN)
    shortcode = m[1] || m[2]
    # http://instagram.com/developer/embedding/
    uri = URI.parse "http://instagram.com/p/#{shortcode}/media/?size=l"
    res = Net::HTTP.new(uri.host).get uri.request_uri, 'User-Agent' => USER_AGENT
    if res.is_a? Net::HTTPRedirection
      res['Location']
    else
      warn 'instagram url failed'
      nil
    end
  end

  ::Gtk::TimeLine.addopenway(/.*\.(?:jpg|png|gif|)\Z/) { |shrinked_url, cancel|
    url = MessageConverters.expand_url_one(shrinked_url)
    Delayer.new { display(url, cancel) }
  }

end
