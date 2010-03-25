
require 'gtk2'
require 'time'
miquire :mui, 'mumble'

module Gtk
  class TimeLine < Gtk::ScrolledWindow

    def initialize()
      super()
      Lock.synchronize do
        self.border_width = 0
        self.set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_ALWAYS)
        @evbox, @tl = gen_timeline
        self.add_with_viewport(@evbox)
        @tooltip = Gtk::Tooltips.new()
      end
      @mumbles = []
    end

    def add(message)
      if message.is_a?(Array) then
        self.block_add_all(message)
      else
        self.block_add(message)
      end
    end

    def block_add(message)
      Lock.synchronize do
        mumble = Gtk::Mumble.new(message)
        @tl.pack(mumble)
        if(@tl.children.size > 200) then
          @tl.remove(@tl.children.last)
        end
      end
    end

    def block_add_all(messages)
      Lock.synchronize do
        @tl.pack_all(messages.map{ |m| Gtk::Mumble.new(m) })
        if(@tl.children.size > 200) then
          (@tl.children.size - 200).times{ @tl.remove(@tl.children.last) }
        end
      end
    end

    def gen_timeline
      Lock.synchronize do
        container = Gtk::EventBox.new
        box = Gtk::PriorityVBox.new(false, 0){ |widget| widget[:id].to_i }
        container.add(box)
        #box.spacing = 16
        style = Gtk::Style.new()
        style.set_bg(Gtk::STATE_NORMAL, *[255,255,255].map{|a| a*255})
        container.style = style
        return container, box
      end
    end

  end

end
