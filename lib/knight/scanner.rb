module Knight
  class Parser
    def self.run_plugins(target, plugins, scanner: nil)
      results = []

      raise('No plugins selected') if plugins.empty?

      plugins.each do |name, plugin|
        begin

          result = plugin.scan(target)

        rescue => e
          error("ERROR: Plugin #{name} failed for #{target}. #{e}")
          raise if $WWDEBUG == true
        end
        results << [name, result] unless result.nil? || result.empty?
      end
      results
    end

    def self.parse(target, result, logging_list: nil, grep_plugin: false)
      logging_list.each do |log|
        begin
          if grep_plugin
            if result.map { |plugin_name, _plugin_result| plugin_name }.include? 'Grep'
              log.out(target, target.status, result)
            end
          else
            log.out(target, target.status, result)
          end
        rescue => e
          error("ERROR Logging failed: #{target} - #{e}")
          raise if $WWDEBUG == true
        end
      end unless logging_list.nil?

      result = {
        'target' => target,
        'status' => target.status,
        'result' => result
      }

      return result unless grep_plugin
      return result if result.map { |plugin_name, _plugin_result| plugin_name }.include? 'Grep'
    end
  end
end