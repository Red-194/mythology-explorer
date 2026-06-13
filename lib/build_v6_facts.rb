# app/scripts/build_v6_facts.rb
#
# Builds v6 master_facts_final.json from v5 facts + v6 ontology.
# Applies all v6 ontology inference rules:
#   - symmetric: reverse the edge
#   - inverse: reverse with inverse predicate
#   - derived: compute from rule definitions

require "json"
require "set"
require "securerandom"
require "fileutils"

V5_PATH     = Rails.root.join("data", "glossary_analysis", "v5", "master_facts_final.json")
V6_ONT_PATH = Rails.root.join("data", "glossary_analysis", "v6", "ontology.json")
V6_OUT_PATH = Rails.root.join("data", "glossary_analysis", "v6", "master_facts_final.json")

def run
  facts = JSON.parse(File.read(V5_PATH))
  ontology = JSON.parse(File.read(V6_ONT_PATH))

  existing = facts.map { |f| fkey(f) }.to_set
  derived = []

  facts.each do |f|
    # Symmetric: if A -> P -> B, add B -> P -> A
    if ontology.dig(f["predicate"], "symmetric")
      rev = make(f["object"], f["predicate"], f["subject"], f)
      push(rev, existing, derived)
    end

    # Inverse: if A -> P -> B, add B -> inverse(P) -> A
    inv = ontology.dig(f["predicate"], "inverse")
    if inv
      rev = make(f["object"], inv, f["subject"], f)
      push(rev, existing, derived)
    end
  end

  # Build lookup indexes from ALL facts (original + derived so far)
  all = facts + derived
  parent_map = Hash.new { |h, k| h[k] = Set.new }  # parent -> [children]
  child_map  = Hash.new { |h, k| h[k] = Set.new }  # child  -> [parents]
  sib_map    = Hash.new { |h, k| h[k] = Set.new }  # person -> [siblings]
  spouse_map = Hash.new { |h, k| h[k] = Set.new }  # person -> [spouses]

  all.each do |f|
    if f["predicate"] == "parent_of"
      parent_map[f["subject"]] << f["object"]
      child_map[f["object"]]  << f["subject"]
    end
    if f["predicate"] == "child_of"
      child_map[f["subject"]]  << f["object"]
      parent_map[f["object"]] << f["subject"]
    end
    if f["predicate"] == "sibling_of"
      sib_map[f["subject"]] << f["object"]
      sib_map[f["object"]]  << f["subject"]
    end
    if f["predicate"] == "spouse_of"
      spouse_map[f["subject"]] << f["object"]
      spouse_map[f["object"]]  << f["subject"]
    end
  end

  # grandparent_of: A -> parent_of -> B -> parent_of -> C => A -> grandparent_of -> C
  gp = 0
  parent_map.each do |a, bs|
    bs.each do |b|
      next unless parent_map.key?(b)
      parent_map[b].each do |c|
        next if a == c
        ev = "Grandparent of #{c} via #{b}"
        f = make(a, "grandparent_of", c, nil, [a, b], ev)
        gp += push(f, existing, derived)
      end
    end
  end

  # grandchild_of (inverse of grandparent_of)
  gc = 0
  derived.select { |f| f["predicate"] == "grandparent_of" }.each do |f|
    r = make(f["object"], "grandchild_of", f["subject"], f)
    gc += push(r, existing, derived)
  end

  # uncle_aunt_of: A -> sibling_of -> B -> parent_of -> C => A -> uncle_aunt_of -> C
  ua = 0
  sib_map.each do |a, bs|
    bs.each do |b|
      next unless parent_map.key?(b)
      parent_map[b].each do |c|
        next if a == c
        ev = "Uncle/aunt of #{c} via sibling #{b}"
        f = make(a, "uncle_aunt_of", c, nil, [a, b], ev)
        ua += push(f, existing, derived)
      end
    end
  end

  # niece_nephew_of (inverse of uncle_aunt_of)
  nn = 0
  derived.select { |f| f["predicate"] == "uncle_aunt_of" }.each do |f|
    r = make(f["object"], "niece_nephew_of", f["subject"], f)
    nn += push(r, existing, derived)
  end

  # step_parent_of: A -> spouse_of -> B -> parent_of -> C => A -> step_parent_of -> C
  sp = 0
  spouse_map.each do |a, bs|
    bs.each do |b|
      next unless parent_map.key?(b)
      parent_map[b].each do |c|
        next if a == c
        ev = "Step-parent of #{c} via spouse #{b}"
        f = make(a, "step_parent_of", c, nil, [a, b], ev)
        sp += push(f, existing, derived)
      end
    end
  end

  # step_child_of (inverse of step_parent_of)
  sc = 0
  derived.select { |f| f["predicate"] == "step_parent_of" }.each do |f|
    r = make(f["object"], "step_child_of", f["subject"], f)
    sc += push(r, existing, derived)
  end

  # cousin_of: A -> child_of -> B, C -> child_of -> D, B -> sibling_of -> D => A -> cousin_of -> C
  co = 0
  child_map.each do |a, parents_a|
    parents_a.each do |b|
      next unless sib_map.key?(b)
      sib_map[b].each do |d|
        next unless child_map.any? { |c, parents_c| parents_c.include?(d) && c != a }
        child_map.each do |c, parents_c|
          next if c == a || !parents_c.include?(d)
          pair = [a, c].sort
          ev = "Cousins: #{a} (child of #{b}) and #{c} (child of #{d})"
          f = make(pair[0], "cousin_of", pair[1], nil, [b, d], ev)
          co += push(f, existing, derived)
        end
      end
    end
  end

  # ancestor_of: transitive closure of parent_of
  anc = 0
  parent_map.keys.each do |root|
    descendants = bfs(parent_map, root)
    descendants.each do |desc|
      next if desc == root
      ev = "Ancestor of #{desc}"
      f = make(root, "ancestor_of", desc, nil, [root], ev)
      anc += push(f, existing, derived)
      r = make(desc, "descendant_of", root, nil, [root], ev)
      anc += push(r, existing, derived)
    end
  end

  # Gender-specific from evidence text
  gen = 0
  facts.each do |f|
    ev = (f["evidence"] || []).join(" ")
    next unless %w[child_of parent_of].include?(f["predicate"])

    if f["predicate"] == "child_of"
      if ev.match?(/\bson\b/i)
        gen += push(make(f["subject"], "son_of", f["object"], f), existing, derived)
      end
      if ev.match?(/\bdaughter\b/i)
        gen += push(make(f["subject"], "daughter_of", f["object"], f), existing, derived)
      end
    end

    if f["predicate"] == "parent_of"
      if ev.match?(/\bfather\b/i)
        gen += push(make(f["subject"], "father_of", f["object"], f), existing, derived)
      end
      if ev.match?(/\bmother\b/i)
        gen += push(make(f["subject"], "mother_of", f["object"], f), existing, derived)
      end
    end
  end

  # sibling_of -> brother_of/sister_of from evidence
  facts.each do |f|
    next unless f["predicate"] == "sibling_of"
    ev = (f["evidence"] || []).join(" ")
    if ev.match?(/\bbrother\b/i)
      gen += push(make(f["subject"], "brother_of", f["object"], f), existing, derived)
    end
    if ev.match?(/\bsister\b/i)
      gen += push(make(f["subject"], "sister_of", f["object"], f), existing, derived)
    end
  end

  # ---- Output ----
  all_facts = facts + derived
  FileUtils.mkdir_p(V6_OUT_PATH.dirname)
  File.write(V6_OUT_PATH, JSON.pretty_generate(all_facts))

  puts "V5 facts:      #{facts.size}"
  puts "V6 total:      #{all_facts.size}"
  puts "New derived:   #{derived.size}"
  puts "  Symmetric:   #{derived.count { |f| ontology.dig(f['predicate'], 'symmetric') }}"
  puts "  Inverse:     #{derived.count { |f| !ontology.dig(f['predicate'], 'symmetric') && !ontology.dig(f['predicate'], 'derived') && f['evidence'].any? { |e| e.match?(/inverse|via/) } }}"
  puts "  Gender:      #{gen}"
  puts "  Grandparent: #{gp}"
  puts "  Grandchild:  #{gc}"
  puts "  Uncle/Aunt:  #{ua}"
  puts "  Niece/Neph:  #{nn}"
  puts "  Step-parent: #{sp}"
  puts "  Step-child:  #{sc}"
  puts "  Cousin:      #{co}"
  puts "  Ancestor:    #{anc}"
  puts ""
  puts "By predicate:"
  all_facts.group_by { |f| f["predicate"] }.sort.each { |p, fs| puts "  #{p}: #{fs.size}" }
  puts ""
  puts "Saved to: #{V6_OUT_PATH}"
end

def bfs(parent_map, start)
  visited = Set.new
  queue = parent_map[start]&.to_a || []
  while queue.any?
    node = queue.shift
    next if visited.include?(node)
    visited << node
    children = parent_map[node]
    queue += children.to_a if children
  end
  visited
end

def make(subject, predicate, object, source_fact, source_terms = nil, evidence = nil)
  {
    "subject" => subject,
    "predicate" => predicate,
    "object" => object,
    "evidence" => evidence ? [evidence] : (source_fact && source_fact["evidence"] ? source_fact["evidence"] : []),
    "source_term" => source_terms || (source_fact && source_fact["source_term"] ? source_fact["source_term"] : []),
    "pages" => source_fact && source_fact["pages"] ? source_fact["pages"] : [],
    "id" => SecureRandom.hex(6)
  }
end

def push(fact, existing, derived)
  key = fkey(fact)
  return 0 if existing.include?(key)
  existing << key
  derived << fact
  1
end

def fkey(f)
  "#{f['subject']}||#{f['predicate']}||#{f['object']}"
end

run
