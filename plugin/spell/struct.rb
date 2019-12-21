# -*- coding: utf-8 -*-

module Plugin::Spell

  Spell = Struct.new(:name, :constraint, :condition, :proc) do
    def match(models, optional)
      Set.new(constraint.map{|a| Diva::Model(a) }) == Set.new(models.map{|a| a.class }) and condition?(models, optional)
    end

    def call(models, optional)
      call_spell_block(models, optional, &proc)
    end

    def condition?(models, optional)
      if condition
        call_spell_block(models, optional, exception_message: false, &condition)
      else
        true
      end
    rescue Plugin::Spell::ArgumentError => err
      false
    end

    def to_s
      "#{name}[#{constraint.to_a.join(',')}]"
    end

    private
    def call_spell_block(models, optional, exception_message: true, &block)
      order = constraint.map{|a| Diva::Model(a) }
      models_sorted = models.sort_by{|m| order.index(m.class) }
      optional ||= {}.freeze
      args = Array.new
      kwargs = Hash.new
      block.parameters.each do |kind, name|
        case kind
        when :req, :opt
          raise Plugin::Spell::ArgumentError, exception_message && "too few argument (expect: #{block.arity}, given: #{models.size}) for #{self}" if models_sorted.empty?
          args << models_sorted.shift
        when :keyreq
          raise Plugin::Spell::ArgumentError, exception_message && "required option #{name} of #{self} was not set." unless optional.has_key?(name)
          kwargs[name] = optional[name]
        when :key
          kwargs[name] = optional[name] if optional.has_key?(name)
        when :keyrest
          kwargs = optional
        end
      end
      raise Plugin::Spell::ArgumentError, exception_message && "too many argument (expect: #{block.arity}, given: #{models.size}) for #{self}" unless models_sorted.empty?
      if kwargs.empty?
        block.call(*args)
      else
        block.call(*args, **kwargs)
      end
    end
  end
end
