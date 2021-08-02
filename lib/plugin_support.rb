class PluginSupport
    def self.load_plugin(f)
        load f
    
    rescue ArgumentError => err
        if err.message =~ /wrong number of arguments \(given 1, expected 0\)/
            error("Error loading plugin #{f}. This plugin may be using a deprecated plugin format for knight version < 0.5.0. Error message: #{err.message}")
        end
        raise if $WWDEBUG == true
    
    rescue SyntaxError => err
        error("Error loading plugin #{f}. Error details: #{err.message}")
        raise if $WWDEBUG == true
    
    rescue Interrupts
        error("Interrupt detected. Failed to load plugin #{f}.")
        raise if $WWDEBUG == true
        exit 1
    end

    def self.precompile_regular_expressions
        Plugin.registered_plugins.each do |thisplugin|
          matches = thisplugin[1].matches
          next if matches.nil?
          matches.each do |thismatch|
            unless thismatch[:regexp].nil?
              # pp thismatch
              thismatch[:regexp_compiled] = Regexp.new(thismatch[:regexp])
            end
    
            [:version, :os, :string, :account, :model, :firmware, :module, :filepath].each do |label|
              if !thismatch[label].nil? && thismatch[label].class == Regexp
                thismatch[:regexp_compiled] = Regexp.new(thismatch[label])
                # pp thismatch
              end
            end
    
            unless thismatch[:text].nil?
              thismatch[:regexp_compiled] = Regexp.new(Regexp.escape(thismatch[:text]))
            end
          end
        end
    end

    def self.load_plugins(list = nil)
        a = []
        b = []

        plugin_dirs = PLUGIN_DIRS.clone
        plugin_dirs.map { |p| p = File.expand_path(p) }

        unless list
            plugin_dirs.each do |d|
              Dir.glob("#{d}/*.rb").each { |x| PluginSupport.load_plugin(x) }
            end
            return Plugin.registered_plugins
          end
        
        list.split(',').each do |p|
            choice = PluginChoice.new
            choice.fill(p)
            a << choice if choice.type == 'file'
            b << choice if choice.type == 'plugin'
        end


