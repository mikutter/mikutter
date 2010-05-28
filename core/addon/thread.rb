
miquire :mui, 'skin'
miquire :addon, 'addon'

class Addon::Thread < Addon::Addon
  def onboot(service)
    Delayer.new{
      container = Gtk::VBox.new(false, 0)
      @main = Gtk::TimeLine.new()
      container.pack_start(@main, true)
      self.regist_tab(service, container, 'Thread', MUI::Skin.get("list.png"))
      Gtk::Mumble.contextmenu.registmenu('スレッドを表示', lambda{ |m, w|
                                           m.message.repliable? }){ |m, w|
        @main.clear
        set_ancestor(m.message).focus } }
    @service = service end

  def onupdate(service, message)
    if message.receive_message and @main.all_id.include?(message.receive_message(true)[:id].to_i)
      @main.add([message]) end end

  private

  def set_children(message)
    if message.children.is_a? Array
      Thread.new{
        Delayer.new{ @main.add(message.children) }
        message.children.each{ |m|
          puts m.to_show
          set_children(m) } } end end

  def set_ancestor(message)
    Thread.new{
      message.each_ancestors(true){ |m|
        set_children(m)
        Delayer.new{ @main.add([m]) } } }
    self end end

Plugin::Ring.push Addon::Thread.new,[:boot, :update]
