# frozen_string_literal: true

module Plugin::GUI
  class Event < Diva::Model
    field.string :event, required: true
    # いつかWidgetをDiva::Modelにするんや（決意）
    # field.string :widget, required: true
    field.has :messages, [Diva::Model]
    field.has :world, Diva::Model, required: true

    def widget
      self[:widget]
    end
  end
end
