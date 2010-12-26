require 'gtk2'
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'utils'))
miquire :core, 'message'
miquire :mui, 'mtk'
miquire :mui, 'extension'
miquire :mui, 'skin'
miquire :mui, 'webicon'
miquire :miku, 'miku'

class Gtk::MessagePicker < Gtk::EventBox
  attr_reader :to_a

  def initialize(conditions, &block)
    super()
    @changed_hook = block
    shell = Gtk::VBox.new
    @container = Gtk::VBox.new
    @function, *exprs = *conditions.to_a
    @function ||= :and
    shell.add(@container)
    shell.closeup(add_button.center)
    exprs.each{|x| add_condition(x) }
    add(Gtk::Frame.new.set_border_width(8).set_label_widget(Mtk::boolean(lambda{ |new|
                                                                           unless new === nil
                                                                             @function = function(new)
                                                                             call end
                                                                           @function == :or },
                                                                         'いずれかにマッチする')).add(shell))
    recalc_to_a
  end

  def function(new = @function)
    (new ? :or : :and) end

  def add_button
    container = Gtk::HBox.new
    btn = Gtk::Button.new('条件を追加')
    btn.signal_connect(:clicked){
      add_condition.show_all }
    btn2 = Gtk::Button.new('サブフィルタを追加')
    btn2.signal_connect(:clicked){
      add_condition([:and, [:==, :user, '']]).show_all }
    container.closeup(btn).closeup(btn2) end
  memoize :add_button

  def add_condition(expr = [:==, :user, ''])
    pack = Gtk::HBox.new
    close = Gtk::Button.new.add(Gtk::WebIcon.new(MUI::Skin.get('close.png'), 16, 16)).set_relief(Gtk::RELIEF_NONE)
    close.signal_connect(:clicked){
      @container.remove(pack)
      pack.destroy
      call
      false }
    pack.closeup(close.top)
    if(expr.first == :and or expr.first == :or)
      pack.add(Gtk::MessagePicker.new(expr, &method(:call)))
    else
      pack.add(Gtk::MessagePicker::PickCondition.new(expr, &method(:call))) end
    @container.closeup(pack) end

  private

  def call
    recalc_to_a
    if @changed_hook
      @changed_hook.call end end

  def recalc_to_a
    @to_a = [@function, *@container.children.map{|x| x.children.last.to_a}].freeze end

  class Gtk::MessagePicker::PickCondition < Gtk::HBox
    def initialize(conditions = [:==, :user, ''], *args, &block)
      super(*args)
      @changed_hook = block
      @condition, @subject, @expr = *conditions.to_a
      build
    end

    def to_a
      [@condition, @subject, @expr] end

    private

  def call
    if @changed_hook
      @changed_hook.call end end

    def build
      closeup(Mtk::chooseone(lambda{ |new|
                               unless new === nil
                                 @subject = new.to_sym
                                 call end
                               @subject.to_s },
                             nil,
                             'user' => 'ユーザ名',
                             'body' => '本文'))
      closeup(Mtk::chooseone(lambda{ |new|
                               unless new === nil
                                 @condition = new.to_sym
                                 call end
                               @condition.to_s },
                             nil,
                             '==' => '＝',
                             '!=' => '≠',
                             'include?' => '⊇',
                             'match_regexp' => '〜'))
      add(Mtk::input(lambda{ |new|
                       unless new === nil
                         @expr = new
                         call end
                       @expr },
                             nil))
    end
  end

end


