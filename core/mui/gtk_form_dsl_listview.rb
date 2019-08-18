# frozen_string_literal: true

class Gtk::FormDSL::ListView < Gtk::TreeView
  def initialize(parent_dslobj, columns, config, object_initializer, &generate)
    raise 'no block given' unless generate
    @parent_dslobj = parent_dslobj
    @columns = columns
    @config = config
    @object_initializer = object_initializer
    @generate = generate
    super()
    store = Gtk::ListStore.new(Object, *([String] * columns.size))

    columns.each_with_index do |(label, _), index|
      col = Gtk::TreeViewColumn.new(label, Gtk::CellRendererText.new, text: index+1)
      #col.resizable = scheme[:resizable]
      append_column(col)
    end

    set_model(store)

    @parent_dslobj[@config].each do |obj|
      append(obj)
    end
  end

  def buttons(container_class)
    container = container_class.new

    # create = Gtk::Button.new(Gtk::Stock::ADD)
    # create.ssc(:clicked) do
    #   Plugin[:gui].dialog('hogefuga の作成', &generate).next do |values|
    #     result = @model_klass.new(values.to_h)
    #     append(result)
    #     rewind
    #   end
    #   true
    # end
    # container.add(create)

    if @generate
      edit = Gtk::Button.new(Gtk::Stock::EDIT)
      edit.ssc(:clicked) do
        _, _, iter = selection.to_enum(:selected_each).first
        target = iter[0]
        proc = @generate
        Plugin[:gui].dialog('hogefuga の編集') do
          set_value target.to_hash
          instance_exec(target, &proc)
        end.next do |values|
          iter[0] = @object_initializer.(values.to_h)
          notice "update object: #{values.to_h.inspect}"
          update(iter)
          rewind
        end.terminate('hoge')
        true
      end
      container.add(edit)
    end

    container
  end

  private def append(obj)
    iter = self.model.append
    iter[0] = obj
    update(iter)
  end

  private def update(iter)
    pp iter[0]
    @columns.each_with_index do |(_, converter), index|
      iter[index + 1] = converter.(iter[0]).to_s
    end
  end

  private def rewind
    @parent_dslobj[@config] = self.model.to_enum(:each).map do |_, _, iter|
      iter[0]
    end
  end
end
