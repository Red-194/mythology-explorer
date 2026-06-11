questions = [
  # Failed ontology mapping
  "What is related to Kwannon?",

  # Model tried answering instead of parsing
  "Who founded Kyoto?",
  "Who founded Kyōto?",
  "Who fathered Susanoo?",

  # Previously produced deity_of unexpectedly
  "Tell me about Amaterasu",
  "What is Amaterasu?",

  # Garbage input
  "banana",
  "what",
  "asdfghjkl",
  "tell me everything",
  "who",

  # Alias stress tests
  "Who are Kushinada's parents?",
  "Who are Susanowo's parents?",
  "Who are Susanuwu's parents?",
  "Who are Ningi's parents?",

  # Associated_with synonyms
  "What is associated with Kwannon?",
  "Who is associated with Kwannon?",
  "What is connected to Kwannon?",
  "What is related to Kwannon?",

  # Slays vs defeats
  "Who killed Orochi?",
  "Who slew Orochi?",
  "Who slayed Orochi?",
  "Who defeated Orochi?"
]

questions.each_with_index do |question, index|
  puts
  puts "=" * 100
  puts "#{index + 1}. #{question}"
  puts "-" * 100

  begin
    result = Tasks::QueryParser.parse(question)

    pp result
  rescue => error
    puts "ERROR"
    puts error.class
    puts error.message
  end
end
