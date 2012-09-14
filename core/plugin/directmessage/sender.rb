# -*- coding: utf-8 -*-

module Plugin::DirectMessage
  class Sender
    attr_reader :service

    def initialize(service, user)
      @service, @user = service, user
    end

    def post(args)
      @service.send_direct_message({:text => args[:message], :user => @user}, &Proc.new)
    end
  end

end
