# -*- coding: utf-8 -*-

miquire :core, 'retriever', 'skin'
miquire :lib, 'retriever/mixin/user_mixin'

class Mikutter::System::User < Retriever::Model
  include Retriever::Model::UserMixin
  field.string :idname
  field.string :name
  field.string :detail
  field.string :profile_image_url

  memoize def self.system
    Mikutter::System::User.new(idname: 'mikutter_bot',
                               name: Environment::NAME,
                               profile_image_url: Skin.get("icon.png"))
  end

  def system?
    true end

end







