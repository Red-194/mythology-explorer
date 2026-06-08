require "json"
require "securerandom"

path = "data/glossary_analysis/v3"
MASTER_FILE = "#{path}/master_facts_with_ids.json"
PATCH_FILE  = "#{path}/patch.json"
OUTPUT_FILE = "#{path}/master_facts_pass_1.json"

facts = JSON.parse(File.read(MASTER_FILE))
patches = JSON.parse(File.read(PATCH_FILE))

fact_map = facts.to_h { |fact| [ fact["id"], fact ] }

correct_count = 0
split_count   = 0
flag_count    = 0

patches.each do |patch|
  action  = patch["action"]
  fact_id = patch["fact_id"]

  unless fact_map.key?(fact_id)
    warn "WARNING: Fact #{fact_id} not found"
    next
  end

  case action

  when "CORRECT"
    replacement = patch["replacement"]

    replacement["id"] = fact_id

    fact_map[fact_id] = replacement

    correct_count += 1

  when "SPLIT"
    original = fact_map.delete(fact_id)

    unless original
      warn "WARNING: Split target #{fact_id} not found"
      next
    end

    patch["replacement"].each do |new_fact|
      new_fact = new_fact.dup
      new_fact["id"] = SecureRandom.hex(6)

      fact_map[new_fact["id"]] = new_fact
    end

    split_count += 1

  when "FLAG"
    flag_count += 1

    # Ignore for now

  else
    warn "WARNING: Unknown action '#{action}'"
  end
end

result = fact_map.values

File.write(
  OUTPUT_FILE,
  JSON.pretty_generate(result)
)

puts
puts "Patch summary"
puts "-------------"
puts "CORRECT: #{correct_count}"
puts "SPLIT:   #{split_count}"
puts "FLAG:    #{flag_count}"
puts
puts "Original facts: #{facts.length}"
puts "Final facts:    #{result.length}"
puts
puts "Written to #{OUTPUT_FILE}"
