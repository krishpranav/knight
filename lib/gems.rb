def gem_available?(gemname)
    Gem::Specification.find_by_name(gemname) ? true : false
  rescue LoadError
    false
  end
  
  required_gems = %w[ipaddr addressable json]
  
  missing_gems = required_gems.map.select { |g| g unless gem_available?(g) }
  
  unless missing_gems.empty?
    puts "knight is not installed and is missing dependencies.\nThe following gems are missing:"
  
    missing_gems.sort.each do |g|
      puts " - #{g}"
    end
  
    puts "\nTo install run the following command from the knight folder:\n'bundle install'\n\n"
    exit 1
  end
  
  required_gems.each { |g| require g }
  
  optional_gems = %w[mongo rchardet pry rb-readline]
  optional_gems.each do |g|
    next unless gem_available?(g)
  
    begin
      require g
    rescue LoadError
      raise if $WWDEBUG == true
    end
  end