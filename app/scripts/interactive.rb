def print_tokens
  usage = Tasks::AnswerGenerator.total_usage
  return unless usage

  prompt = usage["prompt_tokens"]
  completion = usage["completion_tokens"]
  total = usage["total_tokens"]
  saved = usage["tokens_saved"] || 0
  from_cache = usage["from_cache"]

  puts
  if from_cache
    puts "  Tokens: 0 (cached, saved ~#{saved} tokens)"
  elsif total == 0
    puts "  Tokens: 0 (answered locally, saved ~#{saved} tokens)"
  else
    puts "  Tokens: #{prompt} input + #{completion} output = #{total} total"
    puts "  Saved: #{saved} tokens (local parser, 1 LLM call)" if saved > 0
  end
end

puts
puts "=" * 60
puts "  Mythology Explorer  (Japanese Mythology Q&A)"
puts "=" * 60
puts "  Type your question, or 'exit' to quit"
puts "  Type 'help' for examples · 'stats' for cache · 'clear' to reset"
puts "=" * 60

loop do
  puts
  print "> "
  question = $stdin.gets&.strip

  next if question.nil? || question.empty?

  if %w[exit quit q bye].include?(question.downcase)
    puts "Goodbye!"
    break
  end

  if question.downcase == "help"
    puts
    puts "Try asking:"
    puts "  Who are Susanoo's parents?"
    puts "  Who founded Kamakura?"
    puts "  Who is Amaterasu?"
    puts "  Where is Kiyomizu-dera located?"
    puts "  Who serves Amaterasu?"
    puts "  Tell me about Ninigi"
    next
  end

  if question.downcase == "stats"
    stats = Tasks::AnswerGenerator.cache_stats
    puts
    puts "  Cache: #{stats[:size]} entries, #{stats[:hits]} hits, #{stats[:misses]} misses"
    next
  end

  if question.downcase == "clear"
    Tasks::AnswerGenerator.clear_cache
    puts
    puts "  Cache cleared."
    next
  end

  begin
    answer = Tasks::AnswerGenerator.generate(question)
    puts answer
    print_tokens
  rescue => e
    puts "Error: #{e.message}"
  end

  # Prevent Groq RPM/TPM rate limits
  sleep 4
end
