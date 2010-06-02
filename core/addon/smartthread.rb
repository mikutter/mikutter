
miquire :mui, 'skin'
miquire :addon, 'addon'

class Addon::SmartThread < Addon::Addon
  def onboot(service)
    Delayer.new{
      Gtk::Mumble.contextmenu.registmenu('スレッドを表示', lambda{ |m, w|
                                           m.message.repliable? }){ |m, w|
        gen_timeline(m.message) } }
    @service = service
    @timelines = []
    cnt = 0
    @counter = lambda{ cnt += 1 } end

  def onupdate(service, message)
    @timelines.each{ |tl|
      if message.receive_message and tl.all_id.include?(message.receive_message(true)[:id].to_i)
        tl.add([message]) end } end

  private

  def gen_timeline(message)
    tabname = "Thread #{@counter.call}"
    container = Gtk::VBox.new(false, 0)
    timeline = Gtk::TimeLine.new()
    container.closeup(gen_toolbox(tabname, timeline)).add(timeline)
    self.regist_tab(@service, container, tabname, MUI::Skin.get("list.png"))
    @timelines << timeline
    set_ancestor(timeline, message).focus end

  def gen_toolbox(tabname, timeline)
    close = Gtk::Button.new('×')
    close.signal_connect('clicked'){
      @timelines.delete(timeline)
      remove_tab(tabname) }
    Gtk::HBox.new(false, 0).closeup(close)
  end

  def set_children(timeline, message)
    if message.children.is_a? Array
      Thread.new{
        Delayer.new{ timeline.add(message.children) }
        message.children.each{ |m|
          set_children(timeline, m) } } end end

  def set_ancestor(timeline,message)
    Thread.new{
      message.each_ancestors(true){ |m|
        set_children(timeline, m)
        Delayer.new{ timeline.add([m]) } } }
    self end end

Plugin::Ring.push Addon::SmartThread.new,[:boot, :update]
