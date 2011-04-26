# -*- coding: utf-8 -*-
require 'gtk2'
require 'time'
miquire :mui, 'prioritybox'
miquire :mui, 'mumble'

class Gtk::TimeLine < Gtk::ScrolledWindow
  include Enumerable

  @@timelines = WeakSet.new

  # このタイムラインに保存できるメッセージの最大数。超えれば古いものから捨てられる。
  attr_accessor :timeline_max

  # 存在するタイムラインを全て返す
  def self.timelines
    @@timelines = @@timelines.select{ |tl| not tl.destroyed? } end

  # Gtk::Mumble.addlinkrule 参照
  def self.addlinkrule(reg, &proc)
    Gtk::Mumble.addlinkrule(reg, proc) end

  # Gtk::Mumble.addwidgetrule 参照
  def self.addwidgetrule(reg, &proc)
    Gtk::Mumble.addwidgetrule(reg, proc) end

  def initialize()
    mainthread_only
    super()
    @timeline_max = 200
    self.border_width = 0
    self.set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_ALWAYS)
    @mumbles = []
    @@timelines << self
    signal_connect('destroy'){
      clear } end

  # Mumbleごとに繰り返す
  def each(&iter)
    timeline{
      @tl.children.each(&iter) } end

  # _message_ が新たに _user_ のお気に入りに追加されたことを通知する。selfを返す
  def favorite(user, message)
    mumble = get_mumble_by(message)
    mumble.on_favorited(user) if mumble
    self
  end

  # _message_ が _user_ のお気に入りから削除されたことを通知する。selfを返す
  def unfavorite(user, message)
    mumble = get_mumble_by(message)
    mumble.on_unfavorited(user) if mumble
    self
  end

  # このインスタンスにおけるmessageの場所を見直す。messageがこのインスタンス上には
  # 存在しない場合は何もしない。selfを返す。
  def modified(message)
    mainthread_only
    mumble = get_mumble_by(message)
    if mumble
      @tl.reorder(mumble)
    end
    self end

  def add(message)
    timeline{
      if message.is_a?(Enumerable) then
        self.block_add_all(message)
      else
        self.block_add(message) end }
    self end

  def block_add(message)
    type_strict message => Message
    mainthread_only
    mumble = nil
    if message[:rule] == :destroy
      remove_if_exists_all([message])
    else
      message = Plugin.filtering(:show_filter, [message]).first.first
      if message.is_a? Message
        mumble = Gtk::Mumble.new(message).show_all
        @tl.pack(mumble, false)
        if(@tl.children.size > timeline_max)
          w = @tl.children.last
          @tl.remove(w)
          w.destroy end end end
    mumble end

  def block_add_all(messages)
    mainthread_only
    removes, appends = *messages.partition{ |m| m[:rule] == :destroy }
    remove_if_exists_all(removes)
    retweets, appends = *messages.partition{ |m| m[:retweet] }
    add_retweets(retweets)
    appends = Plugin.filtering(:show_filter, appends).first
    appends.each{|a| type_strict a => Message }
    if not appends.empty?
      @tl.pack_all(appends.map{ |m| Gtk::Mumble.new(m).show_all }, false)
      if self.vadjustment.value != 0 or self.has_mumbleinput?
        if self.should_return_top?
          self.vadjustment.value = 0
        else
          self.vadjustment.value += appends.size * Gtk::Mumble::DEFAULT_HEIGHT end end
      if(@tl.children.size > timeline_max)
        (@tl.children.size - timeline_max).times{
          w = @tl.children.last
          @tl.remove(w)
          w.destroy } end end end

  def remove_if_exists_all(msgs)
    if defined? @tl
      msgs.each{ |m|
        w = @tl.children.find{ |x| x[:id] == m[:id] }
        if w
          @tl.remove(w)
          w.destroy end } end
    self end

  def include?(msg)
    all_id.include?(msg[:id].to_i) end

  def all_id
    if defined? @tl
      @tl.children.map{ |x| x[:id].to_i }
    else
      [] end end

  def clear
    if defined? @tl
      mainthread_only
      @tl.children.each{ |elm|
        @tl.remove(elm)
        elm.destroy } end
    self end

  def should_return_top?
    Gtk::PostBox.list.each{ |w|
      return w.posting? if w.get_ancestor(Gtk::TimeLine) == self and w.return_to_top }
    false end

  def has_mumbleinput?
    Gtk::PostBox.list.each{ |w|
      return true if w.get_ancestor(Gtk::TimeLine) == self }
    false end

  def scroll_to(mumble)
    mpos = mumble.window.geometry[1]
    mheight = mumble.window.geometry[3]
    tpos = self.vadjustment.value
    theight = self.window.geometry[3]
    mr = Range.new(mpos, mpos + mheight)
    tr = Range.new(tpos, tpos + theight)
    if not(tr.include?(mr.first) and tr.include?(mr.last))
      if(tr.first > mr.first)
        self.vadjustment.value = mr.first
      else
        self.vadjustment.value = mr.last - theight + mheight end end
    self end

  private

  def timeline
    return nil if self.destroyed?
    if defined? @tl
      yield
    else
      @evbox, @tl = gen_timeline
      yield
      shell = Gtk::VBox.new(false, 0)
      shell.pack_start(@evbox, false)
      shell.pack_start(Gtk::VBox.new)
      self.add_with_viewport(shell).show_all end end

  def add_retweets(messages)
    messages.each{ |message|
      parent = get_mumble_by(message[:retweet])
      if parent
        parent.on_retweeted(message.user)
      elsif message[:retweet]
        mumble = block_add(message.retweet_source)
        if mumble
          mumble.on_retweeted(message.user) end end } end

  def gen_timeline
    mainthread_only
    container = Gtk::EventBox.new
    box = Gtk::PriorityVBox.new(false, 0){ |widget| [widget.modified, widget[:id].to_i] }
    container.add(box)
    style = Gtk::Style.new()
    style.set_bg(Gtk::STATE_NORMAL, *[255,255,255].map{|a| a*255})
    container.style = style
    return container, box
  end

  def get_mumble_by(message)
    type_strict message => tcor(Message, Integer)
    message = message[:id].to_i if message.is_a? Message
    find{ |m| m[:id].to_i == message } end

end

miquire :plugin, 'plugin'

Module.new do
  plugin = Plugin::create(:core)
  plugin.add_event(:favorite){ |service, fav_by, message|
    Gtk::TimeLine.timelines.each{ |tl|
      tl.favorite(fav_by, message) if tl.include?(message) }
  }
  plugin.add_event(:unfavorite){ |service, fav_by, message|
    Gtk::TimeLine.timelines.each{ |tl|
      tl.unfavorite(fav_by, message) if tl.include?(message) }
  }
  plugin.add_event(:message_modified){ |message|
    Gtk::TimeLine.timelines.each{ |tl|
      tl.modified(message) if tl.include?(message) }
  }
  plugin.add_event(:destroyed){ |messages|
    Gtk::TimeLine.timelines.each{ |tl|
      tl.remove_if_exists_all(messages) }
  }
end


