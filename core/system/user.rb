# -*- coding: utf-8 -*-

require 'skin'
require 'lib/diva_hacks'

class Mikutter::System::User < Diva::Model
  extend Memoist

  include Diva::Model::UserMixin

  field.string :idname
  field.string :name
  field.string :detail
  field.has :icon, Diva::Model

  memoize def self.system
    Mikutter::System::User.new(idname: 'mikutter_bot',
                               name: Environment::NAME,
                               icon: Skin[:icon])
  end

  def system?
    true end

end







