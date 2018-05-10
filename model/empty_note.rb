module Plugin::Worldon
  class EmptyNote < Diva::Model
    register :score_empty, name: "Empty Note"

    def description
      ''
    end

    def inspect
      "[empty note]"
    end
  end
end

