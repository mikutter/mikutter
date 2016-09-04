# -*- coding: utf-8 -*-
module Retriever
  class RetrieverError < StandardError
  end

  class InvalidTypeError < RetrieverError
  end

  class InvalidEntityError < RetrieverError
  end
end
