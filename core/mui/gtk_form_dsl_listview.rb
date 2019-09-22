# frozen_string_literal: true

class Gtk::FormDSL::ListView < Gtk::TreeView

  class StringField
    def initialize(&cell_gen)
      raise ArgumentError, 'no block given' unless cell_gen
      @cell_generator = cell_gen
    end

    def rewind(iter, index)
      iter[index] = cell(iter[0])
    end

    def cell(record)
      @cell_generator.(record).to_s
    end

    def renderer
      @renderer ||= Gtk::CellRendererText.new
    end

    def type
      :text
    end

    def klass
      String
    end
  end

  class PhotoField
    def initialize(&cell_gen)
      raise ArgumentError, 'no block given' unless cell_gen
      @cell_generator = cell_gen
    end

    def rewind(iter, index)
      iter[index] = cell(iter[0]).load_pixbuf(width: Gdk.scale(16), height: Gdk.scale(16)) do |downloaded|
        iter[index] = downloaded
      end
    end

    def cell(record)
      @cell_generator.(record)
    end

    def renderer
      @renderer ||= Gtk::CellRendererPixbuf.new
    end

    def type
      :pixbuf
    end

    def klass
      GdkPixbuf::Pixbuf
    end
  end

  # _columns_ は、以下のような、少なくとも2要素を持ったArray。
  # [0] このカラムのラベル（String）
  # インデックス1以降には、以下の値を渡すことができる。
  # [Proc] レコードを受け取り、そのカラムの値を取り出して返すProc。単純にテキストとして処理される。
  # [Hash] 以下のフィールドを持ったHash
  #   - :type :: カラムに表示するデータの種類。 :string なら文字列、 :photo なら画像。
  #   - :cell :: レコードを受け取り、そのカラムの値を取り出して返すProc。typeに :string を渡していれば文字列、 :photo を渡していれば Photo Modelを返すこと。
  def initialize(parent_dslobj, columns, config, object_initializer, reorder: true, update: true, create: true, delete: true, &generate)
    raise 'no block given' unless generate
    @parent_dslobj = parent_dslobj
    @columns = columns.map do |column_attr|
      title, *fields = column_attr
      [title, *gen_fields(fields)].freeze
    end.to_a.freeze
    @config = config
    @object_initializer = object_initializer
    @generate = generate
    @updatable = update
    @creatable = create
    @deletable = delete
    @reordable = reorder
    super()
    store = Gtk::ListStore.new(
      Object,
      *@columns.flat_map { |c| c.drop(1) }.map(&:klass)
    )

    index = 1
    @columns.each do |label, *fields|
      col = Gtk::TreeViewColumn.new(label)
      fields.each do |field|
        col.pack_start(field.renderer, false)
        col.add_attribute(field.renderer, field.type, index)
        #col.resizable = scheme[:resizable]
        append_column(col)
        index += 1
      end
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

  def gen_fields(fields)
    fields.map do |field|
      case field
      when Proc
        StringField.new(&field)
      when Hash
        case field[:type]
        when :string
          StringField.new(&field[:cell])
        when :photo
          PhotoField.new(&field[:cell])
        end
      end
    end
  end

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
    columns = @columns
    target = iter[0]
    Plugin[:gui].dialog('hogefuga の削除') do
      label _('次のhogefugaを本当に削除しますか？削除すると二度と戻ってこないよ')
      if target.is_a?(Diva::Model)
        link target
      else
        index = 1
        columns.each do |title, *fields|
          fields.each do
            label '%{title}: %{value}' % {title: title, value: iter[index]}
            index += 1
          end
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
    index = 1
    @columns.each do |_, *fields|
      fields.each do |field|
        field.rewind(iter, index)
        index += 1
      end
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
