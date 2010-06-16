
miquire :mui, 'skin'
miquire :addon, 'addon'

class Addon::SmartThread < Addon::Addon
  Tab = Class.new(Addon::Addon.gen_tabclass('', MUI::Skin.get("list.png"))){
    def on_create
      super
      close = Gtk::Button.new('×')
      close.signal_connect('clicked'){ self.remove }
      header.closeup(close).show_all
      set_ancestor(@options[:message]).focus end

    def set_children(message)
      if message.children.is_a? Array
        Thread.new{
          Delayer.new{ timeline.add(message.children) }
          message.children.each{ |m|
            set_children(m) } } end
      self end

    def set_ancestor(message)
      Thread.new{
        message.each_ancestors(true){ |m|
          set_children(m)
          Delayer.new{ timeline.add([m]) } } }
      self end }

  def onboot(service)
    Delayer.new{
      Gtk::Mumble.contextmenu.registmenu('スレッドを表示', lambda{ |m, w|
                                           m.message.repliable? }){ |m, w|
        gen_timeline(m.message) } }
    @service = service
    cnt = 0
    @counter = lambda{ cnt += 1 } end

  def onupdate(service, message)
    Tab.tabs.each{ |tab|
      if message.receive_message and
          tab.timeline.all_id.include?(message.receive_message(true)[:id].to_i)
        tab.timeline.add([message]) end } end

  private

  def gen_timeline(message)
    tab = Tab.new("Thread #{@counter.call}", @service, :message => message) end end

Plugin::Ring.push Addon::SmartThread.new,[:boot, :update]
