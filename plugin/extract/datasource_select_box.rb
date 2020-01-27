# frozen_string_literal: true

class Plugin::Extract::DatasourceSelectBox < Gtk::HierarchycalSelectBox
  def initialize(sources, &block)
    super(datasources, sources, &block)
  end

  def datasources
    (Plugin.filtering(:extract_datasources, {}) || [{}]).first.map do |id, source_name|
      [id, source_name.is_a?(String) ? source_name.split('/'.freeze) : source_name]
    end
  end
end
