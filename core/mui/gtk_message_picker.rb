# -*- coding: utf-8 -*-
require 'gtk2'
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'utils'))
miquire :core, 'message', 'skin'
miquire :mui, 'mtk'
miquire :mui, 'extension'
miquire :mui, 'webicon'
miquire :miku, 'miku'

class Gtk::MessagePicker < Gtk::EventBox

  def initialize(conditions, &block)
    conditions = [] unless conditions.is_a? MIKU::List
    super()
    @not = (conditions.respond_to?(:car) and (conditions.car == :not))
    if(@not)
      conditions = (conditions[1] or []).freeze end
    @changed_hook = block
    shell = Gtk::VBox.new
    @container = Gtk::VBox.new
    @function, *exprs = *conditions.to_a
    @function ||= :and
    shell.add(@container)
    shell.closeup(add_button.center)
    exprs.each{|x| add_condition(x) }
    add(Gtk::Frame.new.set_border_width(8).set_label_widget(option_widgets).add(shell))
    p "#{self}: #{to_a}"
  end

  def function(new = @function)
    (new ? :or : :and) end

  def option_widgets
    @option_widgets ||= Gtk::HBox.new.
      closeup(Mtk::boolean(lambda{ |new|
                             unless new.nil?
                               @function = function(new)
                               call end
                             @function == :or },
                           'いずれかにマッチする')).
      closeup(Mtk::boolean(lambda{ |new|
                             unless new.nil?
                               @not = new
                               call end
                             @not },
                           '否定')) end

  def add_button
    @add_button ||= gen_add_button end

  def add_condition(expr = [:==, :user, ''])
    pack = Gtk::HBox.new
    close = Gtk::Button.new.add(Gtk::WebIcon.new(Skin.get('close.png'), 16, 16)).set_relief(Gtk::RELIEF_NONE)
    close.signal_connect(:clicked){
      @container.remove(pack)
      pack.destroy
      call
      false }
    pack.closeup(close.top)
    if(expr.first == :and or expr.first == :or or expr.first == :not)
      pack.add(Gtk::MessagePicker.new(expr, &method(:call)))
    else
      pack.add(Gtk::MessagePicker::PickCondition.new(expr, &method(:call))) end
    @container.closeup(pack) end

  def to_a
    result = [@function, *@container.children.map{|x| x.children.last.to_a}].freeze
    if(@not)
      result = [:not, result].freeze end
    result end

  private

  def call
    if @changed_hook
      @changed_hook.call end end

  def gen_add_button
    container = Gtk::HBox.new
    btn = Gtk::Button.new('条件を追加')
    btn.signal_connect(:clicked){
      add_condition.show_all }
    btn2 = Gtk::Button.new('サブフィルタを追加')
    btn2.signal_connect(:clicked){
      add_condition([:and, [:==, :user, '']]).show_all }
    container.closeup(btn).closeup(btn2) end

  class Gtk::MessagePicker::PickCondition < Gtk::HBox
    def initialize(conditions = [:==, :user, ''], *args, &block)
      super(*args)
      @changed_hook = block
      @condition, @subject, @expr = *conditions.to_a
      build
    end

    def to_a
      [@condition, @subject, @expr].freeze end

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
                             'body' => '本文',
                             'source' => 'Twitterクライアント'))
      closeup(Mtk::chooseone(lambda{ |new|
                               unless new === nil
                                 @condition = new.to_sym
                                 call end
                               @condition.to_s },
                             nil,
                             '==' => '＝',
                             '!=' => '≠',
                             'include?' => '含む',
                             'match_regexp' => '正規表現'))
      add(Mtk::input(lambda{ |new|
                       unless new === nil
                         @expr = new.freeze
                         call end
                       @expr },
                             nil))
    end
  end

end


