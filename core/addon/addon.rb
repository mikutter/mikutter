
miquire :plugin, 'plugin'

module Addon

  def self.regist_tab(container, label, image=nil)
    Plugin.call(:mui_tab_regist, container, label, image) end

  def self.remove_tab(label)
    Plugin.call(:mui_tab_remove, label) end

  def self.focus(label)
    Plugin.call(:mui_tab_active, label) end

  def self.gen_tabclass(default_suffix, default_icon)
    tc = Class.new(Addon::TabBaseClass) do
      @@tabs = []
      def on_create
        @@tabs.push(self) end

      def on_remove
        @@tabs.delete(self) end

      def icon
        if @options[:icon]
          @options[:icon]
        else
          @@default_icon end end

      def actual_name
        @name + @@suffix end

      def self.tabs
        @@tabs end

      def self.default_icon=(di)
        @@default_icon = di end

      def self.suffix=(suffix)
        @@suffix = suffix end end
    tc.default_icon = default_icon
    tc.suffix = default_suffix
    tc end

  class TabBaseClass
    attr_reader :name, :tab, :timeline, :header
    attr_accessor :mark

    def initialize(name, service, options = {})
      @name, @service, @options = name, service, options
      @tab, @mark = gen_main, true
      Addon.regist_tab(@tab, actual_name, icon)
      on_create end

    def update(msgs)
      @timeline.add(msgs.select{|msg| not @timeline.any?{ |m| m[:id] == msg[:id] } }) end

    def remove
      on_remove
      Addon.remove_tab(actual_name) end

    def focus
      Addon.focus(actual_name) end

    private

    def gen_main
      @timeline = Gtk::TimeLine.new
      @header = (@options[:header] or Gtk::HBox.new)
      Gtk::VBox.new(false, 0).closeup(@header).add(@timeline) end end
end


miquire :addon
miquire :user_plugin
