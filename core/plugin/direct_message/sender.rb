# -*- coding: utf-8 -*-

module Plugin::DirectMessage
  class Sender
    def initialize(user)
      @user = user
    end

    def post(args)
      Service.primary.send_direct_message({:text => args[:message], :user => @user}, &Proc.new)
    end
  end

end
