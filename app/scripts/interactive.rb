def print_tokens
  usage = Tasks::AnswerGenerator.total_usage
  return unless usage

  prompt = usage["prompt_tokens"]
  completion = usage["completion_tokens"]
  total = usage["total_tokens"]
  saved = usage["tokens_saved"] || 0

  puts
  if total == 0 && saved > 0
    puts "  Tokens: 0 (classified locally, saved ~#{saved} tokens)"
  else
    puts "  Tokens: #{prompt} input + #{completion} output = #{total} total"
    puts "  Saved: #{saved} tokens (local classification)" if saved > 0
  end
end

puts
puts "=" * 60
puts "  Mythology Explorer  (Japanese Mythology Q&A)"
puts "=" * 60
puts "  Type your question, or 'exit' to quit"
puts "  Type 'help' for example questions"
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
