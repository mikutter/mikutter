# -*- coding: utf-8 -*-
require_relative 'error'
require_relative 'struct'

Plugin.create(:spell) do
  defdsl :defspell do |spell_name, *constraint, condition: nil, &block|
    beh = Plugin::Spell::Spell.new(spell_name.to_sym,
                                  Set.new(constraint).freeze,
                                  condition,
                                  block)
    if !respond_to?(spell_name)
      defdsl spell_name do |*models|
        spell(spell_name, *models)
      end
    end
    filter_search_spell do |yielder, name, models, optional|
      yielder << beh if beh.name == name.to_sym && beh.match(models, optional)
      [yielder, name, models, optional]
    end
  end

  defdsl :spell do |name, *models|
    optional = {}.freeze
    *models, optional = models unless models.last.is_a?(Diva::Model)
    Delayer::Deferred.new.next{
      Enumerator.new{|y|
        Plugin.filtering(:search_spell, y, name.to_sym, models, optional)
      }.first
    }.next{|spell|
      raise Plugin::Spell::SpellNotFoundError, "Spell `#{name}' (#{models.map(&:class).join(', ')}) does not exists." unless spell
      spell.call(models, optional)
    }
  end
end
