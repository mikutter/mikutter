#
# Image.rb
#

miquire :core, 'message'

require 'net/http'

# Image Object
class Message
  class Image
    attr_accessor :url
    attr_reader :resource

    IS_URL = /^https?:\/\//

    def initialize(resource)
      if(not resource.is_a?(IO)) and (FileTest.exist?(resource.to_s)) then
        @resource = open(resource)
      else
        @resource = resource
        if((IS_URL === resource) != nil) then
          @url = resource
        end
      end
    end

    def path
      if(@resource.is_a?(File)) then
        return @resource.path
      end
      return @url
    end

  end
end
