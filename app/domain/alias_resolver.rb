require "json"
require "did_you_mean"

class AliasResolver
  class << self
    def resolve(name)
      return nil if name.blank?

      normalized = normalize(name)

      exact_match = index[normalized]

      return exact_match if exact_match

      fuzzy_resolve(name)
    end

    private

    def index
      @index ||= build_index
    end

    def candidates
      index.keys
    end

    def fuzzy_resolve(name)
      normalized = normalize(name)

      checker = DidYouMean::SpellChecker.new(
        dictionary: index.keys
      )

      match = checker.correct(normalized).first

      return nil unless match

      index[match]
    end

    def build_index
      lookup = {}

      canonical_entities.each do |entity|
        lookup[normalize(entity)] = entity
      end

      aliases.each do |canonical, alias_list|
        lookup[normalize(canonical)] = canonical

        alias_list.each do |alias_name|
          lookup[normalize(alias_name)] = canonical
        end
      end

      lookup
    end

    def canonical_entities
      graph["nodes"].map { |node| node["id"] }
    end

    def aliases
      @aliases ||= JSON.parse(
        File.read(
          Rails.root.join("knowledge", "aliases.json")
        )
      )
    end

    def graph
      @graph ||= JSON.parse(
        File.read(
          Rails.root.join("knowledge", "graph.json")
        )
      )
    end

    def normalize(text)
      text
        .unicode_normalize(:nfkd)
        .encode("ASCII", replace: "")
        .downcase
        .gsub(/[^a-z0-9]/, "")
    end
  end
end
