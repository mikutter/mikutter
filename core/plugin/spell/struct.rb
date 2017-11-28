# -*- coding: utf-8 -*-

module Plugin::Spell

  Spell = Struct.new(:name, :constraint, :condition, :proc) do
    def match(models, optional)
      Set.new(constraint.map{|a| Diva::Model(a) }) == Set.new(models.map{|a| a.class }) and condition?(models, optional)
    end

    def call(models, optional)
      order = constraint.map{|a| Diva::Model(a) }
      proc.call(*models.sort_by{|m| order.index(m.class) }, optional)
    end

    def condition?(models, optional)
      if condition
        order = constraint.map{|a| Diva::Model(a) }
        models_sorted = models.sort_by{|m| order.index(m.class) }
        if condition.arity == models.size
          condition.call(*models_sorted)
        else
          condition.call(*models_sorted, optional)
        end
      else
        true
      end
    end
  end
end
