# app/domain/ontology.rb

require "json"

class Ontology
  class << self
    def predicate?(name)
      predicates.key?(name)
    end

    def inverse(predicate)
      predicates.dig(
        predicate,
        "inverse"
      )
    end

    def symmetric?(predicate)
      predicates.dig(
        predicate,
        "symmetric"
      )
    end

    def description(predicate)
      predicates.dig(
        predicate,
        "description"
      )
    end

    def predicates_list
      predicates.keys
    end

    def predicates_with_descriptions
      predicates.map do |name, data|
        {
          name: name,
          description: data["description"],
          inverse: data["inverse"],
          symmetric: data["symmetric"]
        }
      end
    end

    def prompt_text
      predicates.map do |name, data|
        lines = []

        lines << "#{name}"
        lines << "Description: #{data['description']}"

        if data["inverse"]
          lines << "Inverse: #{data['inverse']}"
        end

        lines << "Symmetric: #{data['symmetric']}"

        lines.join("\n")
      end.join("\n\n")
    end

    def prompt_text_for(predicate_names)
      return prompt_text if predicate_names.nil? || predicate_names.empty?

      predicates
        .select { |name, _| predicate_names.include?(name) }
        .map do |name, data|
          lines = []
          lines << "#{name}"
          lines << "Description: #{data['description']}"

          if data["inverse"]
            lines << "Inverse: #{data['inverse']}"
          end

          lines << "Symmetric: #{data['symmetric']}"
          lines.join("\n")
        end.join("\n\n")
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
