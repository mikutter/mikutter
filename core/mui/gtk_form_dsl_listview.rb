# frozen_string_literal: true

class Gtk::FormDSL::ListView < Gtk::TreeView
  def initialize(parent_dslobj, columns, config, object_initializer, reorder: true, update: true, create: true, delete: true, &generate)
    raise 'no block given' unless generate
    @parent_dslobj = parent_dslobj
    @columns = columns
    @config = config
    @object_initializer = object_initializer
    @generate = generate
    @updatable = update
    @creatable = create
    @deletable = delete
    @reordable = reorder
    super()
    store = Gtk::ListStore.new(Object, *([String] * columns.size))

    columns.each_with_index do |(label, _), index|
      col = Gtk::TreeViewColumn.new(label, Gtk::CellRendererText.new, text: index+1)
      #col.resizable = scheme[:resizable]
      append_column(col)
    end

    set_model(store)
    set_reorderable(@reordable)

    @parent_dslobj[@config].each do |obj|
      append(obj)
    end

    store.ssc(:row_deleted, &model_row_deleted_handler)
    if @creatable || @updatable || @deletable
      ssc(:button_release_event, &view_button_release_event_handler)
    end
  end

  def buttons(container_class)
    container = container_class.new
    container.closeup(create_button) if @creatable
    container.closeup(update_button) if @updatable
    container.closeup(delete_button) if @deletable
  end

  private

  def create_button
    create = Gtk::Button.new(Gtk::Stock::ADD)
    create.ssc(:clicked) do
      record_create
      true
    end
    create
  end

  def update_button
    edit = Gtk::Button.new(Gtk::Stock::EDIT)
    edit.ssc(:clicked) do
      record_update
      true
    end
    edit
  end

  def delete_button
    delete = Gtk::Button.new(Gtk::Stock::DELETE)
    delete.ssc(:clicked) do
      record_delete
      true
    end
    delete
  end

  def record_create
    proc = @generate
    Plugin[:gui].dialog('hogefuga の作成') do
      instance_exec(nil, &proc)
    end.next do |values|
      append(@object_initializer.(values.to_h))
      notice "create object: #{values.to_h.inspect}"
      rewind
    end.terminate('hoge')
  end

  def record_update
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
  end

  def record_delete
    _, _, iter = selection.to_enum(:selected_each).first
    target = iter[0]
    columns = @columns.map(&:first)
    Plugin[:gui].dialog('hogefuga の削除') do
      label _('次のhogefugaを本当に削除しますか？削除すると二度と戻ってこないよ')
      if target.is_a?(Diva::Model)
        link target
      else
        columns.each_with_index do |title, index|
          label '%{title}: %{value}' % {title: title, value: iter[index + 1]}
        end
      end
    end.next do |values|
      self.model.remove(iter)
      rewind
    end.terminate('hoge')
  end

  def append(obj)
    iter = self.model.append
    iter[0] = obj
    update(iter)
  end

  def update(iter)
    pp iter[0]
    @columns.each_with_index do |(_, converter), index|
      iter[index + 1] = converter.(iter[0]).to_s
    end
  end

  def rewind
    @parent_dslobj[@config] = self.model.to_enum(:each).map do |_, _, iter|
      iter[0]
    end
  end

  def model_row_deleted_handler
    ->(_widget, _) do
      rewind
      false
    end
  end

  def view_button_release_event_handler
    ->(widget, event) do
      if event.button == 3
        Gtk::ContextMenu.new.tap do |cm|
          cm.register('新規作成') { record_create } if @creatable
          cm.register('編集')     { record_update } if @updatable
          cm.register('削除')     { record_delete } if @deletable
          cm.popup(widget, widget)
        end
        true
      end
    end
  end
end
