require 'gtk2'
require 'time'
miquire :mui, 'prioritybox'
miquire :mui, 'mumble'

module Gtk
  class TimeLine < Gtk::ScrolledWindow
    include Enumerable

    def initialize()
      Lock.synchronize do
        super()
        self.border_width = 0
        self.set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_ALWAYS)
        @mumbles = []
        signal_connect('destroy'){ clear } end end

    def timeline
      if defined? @tl
        yield
      else
        @evbox, @tl = gen_timeline
        yield
        shell = Gtk::VBox.new(false, 0)
        shell.pack_start(@evbox, false)
        shell.pack_start(Gtk::VBox.new)
        self.add_with_viewport(shell).show_all end end

    def each(&iter)
      timeline{
        @tl.children.each(&iter) } end

    def add(message)
      timeline{
        if message.is_a?(Enumerable) then
          self.block_add_all(message)
        else
          self.block_add(message) end } end

    def block_add(message)
      Lock.synchronize do
        if message[:rule] == :destroy
          remove_if_exists_all([message])
        else
          mumble = Gtk::Mumble.new(message).show_all
          @tl.pack(mumble, false)
          if(@tl.children.size > 200)
            w = @tl.children.last
            @tl.remove(w)
            w.destroy end end end end

    def block_add_all(messages)
      Lock.synchronize do
        removes, appends = *messages.partition{ |m| m[:rule] == :destroy }
        remove_if_exists_all(removes)
        @tl.pack_all(appends.map{ |m| Gtk::Mumble.new(m).show_all }, false)
        if self.vadjustment.value != 0 or self.has_mumbleinput? then
          if self.should_return_top? then
            self.vadjustment.value = 0
          else
            self.vadjustment.value += appends.size * Gtk::Mumble::DEFAULT_HEIGHT
          end
        end
        if(@tl.children.size > 200) then
          (@tl.children.size - 200).times{
            w = @tl.children.last
            @tl.remove(w)
            w.destroy }
        end
      end
    end

    def remove_if_exists_all(msgs)
      if defined? @tl
        msgs.each{ |m|
          w = @tl.children.find{ |x| x[:id] == m[:id] }
          if w
            @tl.remove(w)
            w.destroy end } end
      self end

    def all_id
      if defined? @tl
        @tl.children.map{ |x| x[:id].to_i }
      else
        [] end end

    def clear
      if defined? @tl
        Lock.synchronize do
          @tl.children.each{ |elm|
            @tl.remove(elm)
            elm.destroy } end end
      self end

    def should_return_top?
      Gtk::PostBox.list.each{ |w|
        return w.posting? if w.get_ancestor(Gtk::TimeLine) == self and w.return_to_top }
      false end

    def has_mumbleinput?
      Gtk::PostBox.list.each{ |w|
        return true if w.get_ancestor(Gtk::TimeLine) == self }
      false end

    def gen_timeline
      Lock.synchronize do
        container = Gtk::EventBox.new
        box = Gtk::PriorityVBox.new(false, 0){ |widget| [widget[:created], widget[:id].to_i] }
        container.add(box)
        #box.spacing = 16
        style = Gtk::Style.new()
        style.set_bg(Gtk::STATE_NORMAL, *[255,255,255].map{|a| a*255})
        container.style = style
        return container, box
      end
    end

    def self.addlinkrule(reg, &proc)
      Gtk::Mumble.addlinkrule(reg, proc) end

    def self.addwidgetrule(reg, &proc)
      Gtk::Mumble.addwidgetrule(reg, proc) end

  end

end
