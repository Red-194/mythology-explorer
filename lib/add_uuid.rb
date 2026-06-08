require "json"
require "securerandom"

path = "data/glossary_analysis/v2"
INPUT_FILE = "#{path}/master_facts.json"
OUTPUT_FILE = "#{path}/master_facts_with_ids.json"

facts = JSON.parse(File.read(INPUT_FILE))

facts.each do |fact|
  fact["id"] ||= SecureRandom.hex(6) # 12 chars
end

File.write(
  OUTPUT_FILE,
  JSON.pretty_generate(facts)
)

puts "Added IDs to #{facts.length} facts"
