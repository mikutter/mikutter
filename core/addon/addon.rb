# -*- coding: utf-8 -*-

miquire :plugin, 'plugin'

module Addon

  def self.regist_tab(container, label, image=nil)
    Plugin.call(:mui_tab_regist, container, label, image) end

  def self.remove_tab(label)
    Plugin.call(:mui_tab_remove, label) end

  def self.focus(label)
    Plugin.call(:mui_tab_active, label) end

  def self.gen_tabclass
    Class.new(gen_tab_base_class) do
      define_method(:on_create) do
        self.class.tabs.push(self) end

      define_method(:on_remove) do
        self.class.tabs.delete(self) end

      def icon
        @options[:icon] end

      def actual_name
        (@name or '') + suffix end

      def suffix
        '' end

      def self.tabs
        @tabs = [] if not @tabs
        @tabs end end end

  def self.gen_tab_base_class
    Class.new do
      attr_reader :name, :tab, :timeline, :header, :options
      attr_accessor :mark

      def initialize(name, service, options = {})
        @name, @service, @options = name, service, options
        @tab, @mark, @destroyed = gen_main, true, false
        Addon.regist_tab(@tab, actual_name, icon)
        on_create end

      def update(msgs)
        unless destroyed?
          @timeline.add(msgs.select{|msg| not @timeline.any?{ |m| m[:id] == msg[:id] } }) end end

      def remove
        on_remove
        @destroyed = true
        Addon.remove_tab(actual_name) end

      def focus
        Addon.focus(actual_name) end

      def destroyed?
        @timeline.destroyed? or @destroyed end

      private

      def gen_main
        @timeline = Gtk::TimeLine.new
        @header = (@options[:header] or Gtk::HBox.new)
        Gtk::VBox.new(false, 0).closeup(@header).add(@timeline) end end end
end


miquire :addon
miquire :user_plugin
# ~> -:2: undefined method `miquire' for main:Object (NoMethodError)
