class LoggingMagicTreeXML < Logging
    def initialize(f = STDOUT)
      super
      @substitutions = { '&' => '&amp;', '"' => '&quot;', '<' => '&lt;', '>' => '&gt;' }
  
      @f.puts '<?xml version="1.0" encoding="UTF-8"?>' if @f.empty?
      @f.puts '<magictree class="MtBranchObject">'
    end
  
    def close
      @f.puts '</magictree>'
      @f.close
    end
  
    def escape(t)
      text = t.to_s.dup

      @substitutions.sort_by { |a, _| a == '&' ? 0 : 1 }.map { |from, to| text.gsub!(from, to) }
  
      r = /[^\x20-\x5A\x5E-\x7E]/
  
      text.gsub!(r) { |x| "%#{x.unpack('H2' * x.size).join('%').upcase}" }
      text
    end
  
    def out(target, _status, results)
      $semaphore.synchronize do

        uri = URI.parse(target.to_s)
        @host_os = []
        @host_port = uri.port
        @host_scheme = uri.scheme
  
        if uri.host =~ /^[\d]{1,3}\.[\d]{1,3}\.[\d]{1,3}\.[\d]{1,3}$/i
          @host_ip = uri.host
          @host_name = nil
        else
          @host_name = uri.host
          @host_ip = nil
        end
  
        results.each do |plugin_name, plugin_results|
          next if plugin_results.empty?
          @host_ip = plugin_results.map { |x| x[:string] unless x[:string].nil? }.to_s if plugin_name =~ /^IP$/

          @host_country = plugin_results.map { |x| x[:string] unless x[:string].nil? }.to_s if plugin_name =~ /^Country$/

          @host_os << plugin_results.map { |x| x[:os] unless x[:os].class == Regexp }.to_s
        end
          
        @f.write "<testdata class=\"MtBranchObject\"><host>#{escape(@host_ip)}"
  
        @f.write "<hostname>#{escape(@host_name)}</hostname>" unless @host_name.nil?
  
        @host_os.compact.sort.uniq.map { |x| @f.write "<os>#{escape(x.to_s)}</os>" unless x.empty? } unless @host_os.empty?
  
        @f.write "<country>#{escape(@host_country)}</country><ipproto>tcp<port>#{escape(@host_port)}<state>open</state>"
  
        @f.write '<tunnel>ssl' if @host_scheme == 'https'
  
        @f.puts '<service>http'
        results.each do |plugin_name, plugin_results|
          next unless !plugin_results.empty? && plugin_name !~ /^IP$/ && plugin_name !~ /^Country$/
          certainty = plugin_results.map { |x| x[:certainty] unless x[:certainty].class == Regexp }.flatten.compact.sort.uniq.last
          versions = plugin_results.map { |x| x[:version] unless x[:version].class == Regexp }.flatten.compact.sort.uniq
          strings = plugin_results.map { |x| x[:string] unless x[:string].class == Regexp }.flatten.compact.sort.uniq
          models = plugin_results.map { |x| x[:model] unless x[:model].class == Regexp }.flatten.compact.sort.uniq
          firmwares = plugin_results.map { |x| x[:firmware] unless x[:firmware].class == Regexp }.flatten.compact.sort.uniq
          filepaths = plugin_results.map { |x| x[:filepath] unless x[:filepath].class == Regexp }.flatten.compact.sort.uniq
          accounts = plugin_results.map { |x| x[:account] unless x[:account].class == Regexp }.flatten.compact.sort.uniq
          modules = plugin_results.map { |x| x[:module] unless x[:module].class == Regexp }.flatten.compact.sort.uniq
  
          @f.write "<url>#{escape(target)}<#{escape(plugin_name)}>"
  
          if certainty && certainty < 100
            @f.write "<certainty>#{escape(certainty)}</certainty>"
          end
  
          unless strings.empty?
            strings.map { |x| @f.write escape(x).to_s } unless plugin_name =~ /^IP$/ || plugin_name =~ /^Country$/
          end
  
          unless versions.empty?
            versions.map { |x| @f.write "<version>#{escape(x)}</version>" }
          end
  
          unless models.empty?
            models.map { |x| @f.puts "<model>#{escape(x)}</model>" }
          end
  
          unless firmwares.empty?
            firmwares.map { |x| @f.write "<firmware>#{escape(x)}</firmware>" }
          end
  
          unless modules.empty?
            modules.map { |x| @f.write "<module>#{escape(x)}</module>" } unless plugin_name =~ /^Country$/
          end
  
          unless accounts.empty?
            accounts.map { |x| @f.write "<user>#{escape(x)}</user>" }
          end

          unless filepaths.empty?
            filepaths.map { |x| @f.write "<filepath>#{escape(x)}</filepath>" }
          end
  
          @f.write "</#{escape(plugin_name)}></url>"
        end
        @f.write '</service>'

        @f.write '</tunnel>' if @host_scheme == 'https'
        @f.write '</port></ipproto></host></testdata>'
      end
    end
  end