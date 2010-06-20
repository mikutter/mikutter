
miquire :plugin, 'plugin'

module Addon
  class Addon < Plugin::Plugin

    def regist_tab(watch, container, label, image=nil)
      #Plugin::GUI.instance.regist_tab(container, label)
      Plugin::Ring::fire(:plugincall, [:gui, watch, :mui_tab_regist, container, label,
                                       (image and Gtk::WebIcon.new(image, 24, 24))])
      @label = label
    end

    def remove_tab(label)
      Plugin::Ring::fire(:plugincall, [:gui, nil, :mui_tab_remove, label])
    end

    def focus
      Plugin::Ring::fire(:plugincall, [:gui, nil, :mui_tab_active, @label])
    end

    def self.gen_tabclass(default_suffix, default_icon)
      Class.new(Addon::TabBaseClass) do
        @@icon, @@default_suffix = default_icon, default_suffix
        @@tabs = []
        def on_create
          @@tabs.push(self) end

        def on_remove
          @@tabs.delete(self) end

        def self.tabs
          @@tabs end

        def icon
          if @options[:icon]
            @options[:icon]
          else
            @@icon end end

        def suffix
          @@default_suffix end
      end
    end

    class TabBaseClass < Addon
      attr_reader :name, :tab, :timeline, :header
      attr_accessor :mark

      def initialize(name, service, options = {})
        @name, @service, @options = name, service, options
        @tab, @mark = gen_main, true
        self.regist_tab(@service, @tab, actual_name, icon)
        on_create end

      def actual_name
        @name + suffix end

      def update(msgs)
        @timeline.add(msgs.select{|msg| not @timeline.any?{ |m| m[:id] == msg[:id] } }) end

      def remove
        on_remove
        self.remove_tab(actual_name) end

      private

      def gen_main
        @timeline = Gtk::TimeLine.new
        @header = (@options[:header] or Gtk::HBox.new)
        Gtk::VBox.new(false, 0).closeup(@header).add(@timeline)
      end end end
end

miquire :addon
miquire :user_plugin
