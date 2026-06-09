require "json"

path = "data/glossary_analysis/v3"
facts = JSON.parse(File.read("#{path}/master_facts_normalized.json"))

predicates = Hash.new(0)

facts.each do |fact|
  predicates[fact["predicate"]] += 1
end

predicates
  .sort_by { |_, count| -count }
  .each do |predicate, count|
    puts "#{predicate}: #{count}"
  end
