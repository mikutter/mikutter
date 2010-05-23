
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
        set_ancestor(m.message).focus } }
    @ancestor = nil
    @service = service end

  def onupdate(service, message)
    ancestors = message.ancestors
    @main.add(ancestors) if not(ancestors.empty?) and @main.include?(ancestors.last) end

  private

  def set_ancestor(message)
    members = message.ancestors(true)
    @ancestor = members.last
    @main.clear
    @main.add([message, *members])
    self end end

Plugin::Ring.push Addon::Thread.new,[:boot]
