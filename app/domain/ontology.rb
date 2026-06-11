# app/domain/ontology.rb

require "json"

class Ontology
  class << self
    def predicate?(name)
      predicates.key?(name)
    end

    def inverse(predicate)
      predicates.dig(predicate, "inverse")
    end

    def symmetric?(predicate)
      predicates.dig(predicate, "symmetric")
    end

    def predicates_list
      predicates.keys
    end

    private

    def predicates
      @predicates ||= JSON.parse(
        File.read(
          Rails.root.join(
            "knowledge",
            "ontology.json"
          )
        )
      )
    end
  end
end
