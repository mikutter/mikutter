# -*- coding: utf-8 -*-

miquire :core, 'retriever', 'skin'

class Mikutter::System::User < Retriever::Model
  self.keys = [[:idname, :string],
               [:name, :string],
               [:detail, :string],
               [:profile_image_url, :string],
               [:protected, :bool],
               [:verified, :bool],
              ]

  memoize def self.system
    Mikutter::System::User.new(idname: 'mikutter_bot',
                               name: Environment::NAME,
                               profile_image_url: Skin.get("icon.png"))
  end

  def system?
    true end

  def idname
    self[:idname]
  end

end







