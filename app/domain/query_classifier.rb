# app/domain/query_classifier.rb
#
# Local intent classifier to skip or minimize LLM calls.
# Detects entity lookups, garbage input, and narrows
# relationship predicates down to 2-3 candidates.

require "set"

class QueryClassifier
  class << self
    def classify(question)
      q = question.downcase.strip

      result = {
        type: nil,
        entity: nil,
        candidate_predicates: [],
        confidence: 0.0,
        skip_llm: false
      }

      if garbage?(q)
        result.merge!(
          type: "entity_lookup",
          entity: nil,
          confidence: 0.9,
          skip_llm: true
        )
        return result
      end

      # Check for relationship queries BEFORE entity lookups
      # "Who is X's wife?" looks like entity_lookup but is actually a relationship
      candidates = match_relationship(q)
      if candidates.any?
        direction = infer_direction(q)
        result.merge!(
          type: direction,
          entity: extract_entity(q),
          candidate_predicates: candidates,
          confidence: 0.7
        )
        return result
      end

      if entity_lookup?(q)
        entity = extract_entity(q)
        result.merge!(
          type: "entity_lookup",
          entity: entity,
          confidence: 0.8,
          skip_llm: true
        )
        return result
      end

      nil
    end

    private

    GARBAGE_PATTERNS = [
      /^$/,
      /^what\s*$/,
      /^who\s*$/,
      /^why\s*$/,
      /^how\s*$/,
      /^tell\s+me\s+everything$/,
      /^[a-z]+$/,
      /^[a-z\s]{1,5}$/
    ].freeze

    ENTITY_LOOKUP_PATTERNS = [
      /^(who|what)\s+is\s+(.+?)\??$/i,
      /^tell\s+me\s+about\s+(.+?)\??$/i,
      /^describe\s+(.+?)\??$/i
    ].freeze

    RELATIONSHIP_RULES = [
      {
        keywords: %w[
          parent father mother parents offspring
          descended ancestor child_of
        ],
        predicates: ["child_of", "parent_of"]
      },
      {
        keywords: %w[
          children kids son daughter child
          descendants offspring born
          fathered mothered
        ],
        predicates: ["child_of", "parent_of"]
      },
      {
        keywords: %w[
          spouse wife husband married marriage
          partner wed
        ],
        predicates: ["spouse_of", "lover_of"]
      },
      {
        keywords: %w[
          kill killed killed slain slay defeat defeated
          conquered conquer
        ],
        predicates: ["slays", "defeats"]
      },
      {
        keywords: %w[
          found founded establish established
          created creator create founder
        ],
        predicates: ["founds", "creates"]
      },
      {
        keywords: %w[
          serve servant attendant retainer
          minister serves serving
        ],
        predicates: ["servant_of"]
      },
      {
        keywords: %w[
          pursue pursuing suitor pursued
          court courting woo
        ],
        predicates: ["suitor_of"]
      },
      {
        keywords: %w[
          where located location region place
          realm reside reside
        ],
        predicates: ["located_in", "lives_in", "born_in"]
      },
      {
        keywords: %w[
          sacred holy shrine temple dedicated
        ],
        predicates: ["sacred_to"]
      },
      {
        keywords: %w[
          friend companion buddy
        ],
        predicates: ["friend_of"]
      },
      {
        keywords: %w[
          sibling brother sister
        ],
        predicates: ["sibling_of"]
      },
      {
        keywords: %w[
          god goddess deity divine ruler
          embodiment embody
        ],
        predicates: ["god_of", "goddess_of", "deity_of", "ruler_of"]
      },
      {
        keywords: %w[
          owns possess possession mastery
          artifact weapon item
        ],
        predicates: ["owns", "creates"]
      },
      {
        keywords: %w[
          travel journey relocated went
          moved
        ],
        predicates: ["travels_to"]
      },
      {
        keywords: %w[
          visit visited visiting staying
        ],
        predicates: ["visits"]
      },
      {
        keywords: %w[
          associated related connected thematic
          linked
        ],
        predicates: ["associated_with"]
      },
      {
        keywords: %w[
          derived originates origin name
          comes_from
        ],
        predicates: ["derived_from"]
      },
      {
        keywords: %w[
          dies died death
        ],
        predicates: ["dies_in"]
      },
      {
        keywords: %w[
          buried entombed tomb grave
        ],
        predicates: ["buried_in"]
      },
      {
        keywords: %w[
          born birth birthplace
        ],
        predicates: ["born_in"]
      },
      {
        keywords: %w[
          lover affair romance
        ],
        predicates: ["lover_of"]
      }
    ].freeze

    REVERSE_PATTERNS = [
      /who\s+is\s+\S+'s\s+(children|kids|descendants)\?/i,
      /who\s+did\s+\S+\s+(father|mother|create|found)\?/i,
      /who\s+(founded|created|established)\b/i,
      /who\s+pursued\b/i,
      /who\s+serve?s\b.*\S+/i,
      /who\s+(is\s+)?married\s+to\b/i,
      /who\s+(is\s+)?the\s+(founder|creator|parent)/i,
      /what\s+(is\s+)?the\s+(location|region|place)\s+of\b/i,
      /who\s+is\s+\S+\s+(married|wed)\s+to\b/i,
      /who\s+is\s+\S+'s\s+(husband|wife|spouse)\b/i,
      /who\s+(are|is)\s+\S+'s\s+(parent|father|mother|children|child|sibling)\b/i,
      /who\s+(are|is)\s+\S+'s\s+(servant|attendant|retainer|suitor)\b/i
    ].freeze

    def garbage?(q)
      GARBAGE_PATTERNS.any? { |p| q.match?(p) }
    end

    def entity_lookup?(q)
      ENTITY_LOOKUP_PATTERNS.any? { |p| q.match?(p) }
    end

    def match_relationship(q)
      matched = Set.new

      RELATIONSHIP_RULES.each do |rule|
        rule[:keywords].each do |kw|
          if q.include?(kw)
            rule[:predicates].each { |p| matched << p }
          end
        end
      end

      matched.to_a
    end

    def infer_direction(q)
      REVERSE_PATTERNS.any? { |p| q.match?(p) } ?
        "reverse_relationship_lookup" :
        "relationship_lookup"
    end

    def extract_entity(q)
      # "Who is X's Y?" or "Who are X's Y?"
      m = q.match(/who\s+(?:is|are)\s+(.+?)'s\s+\S+/i)
      return cleanup(m[1]) if m

      # "Who did X verb?"
      m = q.match(/who\s+did\s+(\S+)/i)
      return cleanup(m[1]) if m

      # "Who verb X?" (e.g. "Who killed Orochi?")
      m = q.match(/who\s+(killed|slay|slain|defeated|defeat|conquered|pursued|served|founded|created)\s+(\S+)/i)
      return cleanup(m[2]) if m

      # "Where is X?" or "Where was X born?"
      m = q.match(/where\s+(?:is|was)\s+(\S+)/i)
      return cleanup(m[1]) if m

      # "What is the Y of X?"
      m = q.match(/what\s+is\s+the\s+\S+\s+of\s+(\S+)/i)
      return cleanup(m[1]) if m

      # "Tell me about X"
      m = q.match(/tell\s+me\s+about\s+(.+?)[\?\s]*$/i)
      return cleanup(m[1]) if m

      # "Who is X Y?" without apostrophe
      m = q.match(/who\s+(?:is|are)\s+(\S+)\s+(?:parent|parents|father|mother|children|child|spouse|wife|husband|brother|sister|sibling|servant|suitor|lover|friend|attendant|kid|descendant)/i)
      return cleanup(m[1]) if m

      # Fallback
      m = q.match(/(?:who|what|where|tell me about|describe)\s+(?:is\s+|are\s+|did\s+|was\s+|do\s+)?(\S+)/i)
      return cleanup(m[1]) if m

      nil
    end

    def cleanup(name)
      name.gsub(/[\?\.!\s]+$/, "").strip
    end
  end
end
