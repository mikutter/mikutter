
require 'gtk2'

module MUI
  class Skin

    def self.get(filename)
      File.join(*[path, filename].flatten)
    end

    def self.path
      %w(skin data)
    end

  end
end
