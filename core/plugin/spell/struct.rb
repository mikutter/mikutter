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
        condition.call(*models.sort_by{|m| order.index(m.class) }, optional)
      else
        true
      end
    end
  end
end
