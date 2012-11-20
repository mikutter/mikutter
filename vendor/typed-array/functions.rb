# Provides the validation functions that get included into a TypedArray

# Namespace TypedArray
module TypedArray

  # The functions that get included into TypedArray
  module Functions
    # Validates outcome. See Array#initialize
    def initialize(*args, &block)
      ary = Array.new *args, &block
      self.replace ary
    end

    # Validates outcome. See Array#replace
    def replace(other_ary)
      _ensure_all_items_in_array_are_allowed other_ary
      super
    end

    # Validates outcome. See Array#&
    def &(ary)
      self.class.new super
    end

    # Validates outcome. See Array#*
    def *(int)
      self.class.new super
    end

    # Validates outcome. See Array#+
    def +(ary)
      self.class.new super
    end

    # Validates outcome. See Array#<<
    def <<(item)
      _ensure_item_is_allowed item
      super
    end

    # Validates outcome. See Array#[]
    def [](idx)
      self.class.new super
    end

    # Validates outcome. See Array#slice
    def slice(*args)
      self.class.new super
    end

    # Validates outcome. See Array#[]=
    def []=(idx, item)
      _ensure_item_is_allowed item
      super
    end

    # Validates outcome. See Array#concat
    def concat(other_ary)
      _ensure_all_items_in_array_are_allowed other_ary
      super
    end

    # Validates outcome. See Array#eql?
    def eql?(other_ary)
      _ensure_all_items_in_array_are_allowed other_ary
      super
    end

    # Validates outcome. See Array#fill
    def fill(*args, &block)
      ary = self.to_a
      ary.fill *args, &block
      self.replace ary
    end

    # Validates outcome. See Array#push
    def push(*items)
      _ensure_all_items_in_array_are_allowed items
      super
    end

    # Validates outcome. See Array#unshift
    def unshift(*items)
      _ensure_all_items_in_array_are_allowed items
      super
    end

    # Validates outcome. See Array#map!
    def map!(&block)
      self.replace(self.map &block)
    end

    protected

    # Ensure that all items in the passed Array are allowed
    def _ensure_all_items_in_array_are_allowed(ary)
      # If we're getting an instance of self, accept
      return if ary.is_a? self.class
      _ensure_item_is_allowed(ary, [Array])
      ary.each { |item| _ensure_item_is_allowed(item) }
    end

    # Ensure that the specific item passed is allowed
    def _ensure_item_is_allowed(item, expected=nil)
      return if item.nil? #allow nil entries
      expected ||= self.class.restricted_types
      return if expected.any? { |allowed| item.class <= allowed }
      raise TypedArray::UnexpectedTypeException.new(expected, item.class)
    end
  end
end
