class LoggingBrief < Logging
    def escape(s)

      r = /[\x00-\x1F]/

      s.gsub(r) { |x| "%#{x.unpack('H2' * x.size).join('%').upcase}" }
    end

    def out(target, status, results)
      brief_results = []

  
      results = results.sort 
  
      results.each do |plugin_name, plugin_results|
        next if plugin_results.empty?
        suj = suj(plugin_results)
  
        certainty = suj[:certainty].to_i
        version = escape(suj[:version])
        os = escape(suj[:os])
        string = escape(suj[:string])
        accounts = escape(suj[:account])
        model = escape(suj[:model])
        firmware = escape(suj[:firmware])
        modules = escape(suj[:module])
        filepath = escape(suj[:filepath])
  
        if (@f == STDOUT && $use_colour == 'auto') || ($use_colour == 'always')
          coloured_string = grey(string)
          coloured_string = cyan(string) if plugin_name == 'HTTPServer'
          coloured_string = yellow(string) if plugin_name == 'Title'
  
          coloured_string = grey(string) if plugin_name == 'MD5'
          coloured_string = grey(string) if plugin_name == 'Header-Hash'
          coloured_string = grey(string) if plugin_name == 'Footer-Hash'
          coloured_string = grey(string) if plugin_name == 'CSS'
          coloured_string = grey(string) if plugin_name == 'Tag-Hash'
  
          coloured_plugin = white(plugin_name)
          coloured_plugin = grey(plugin_name) if plugin_name == 'MD5'
          coloured_plugin = grey(plugin_name) if plugin_name == 'Header-Hash'
          coloured_plugin = grey(plugin_name) if plugin_name == 'Footer-Hash'
          coloured_plugin = grey(plugin_name) if plugin_name == 'CSS'
          coloured_plugin = grey(plugin_name) if plugin_name == 'Tag-Hash'
  
          p = ((certainty && certainty < 100) ? "#{grey(Helper::certainty_to_words(certainty))} " : '') +
              coloured_plugin + (!version.empty? ? "[#{green(version)}]" : '') +
              (!os.empty? ? "[#{red(os)}]" : '') +
              (!string.empty? ? "[#{coloured_string}]" : '') +
              (!accounts.empty? ? "[#{cyan(accounts)}]" : '') +
              (!model.empty? ? "[#{dark_green(model)}]" : '') +
              (!firmware.empty? ? "[#{dark_green(firmware)}]" : '') +
              (!filepath.empty? ? "[#{dark_green(filepath)}]" : '') +
              (!modules.empty? ? "[#{red(modules)}]" : '')
  
          brief_results << p
        else
  
          brief_results << ((certainty && certainty < 100) ? "#{Helper::certainty_to_words(certainty)} " : '') +
                           plugin_name + (!version.empty? ? "[#{version}]" : '') +
                           (!os.empty? ? "[#{os}]" : '') +
                           (!string.empty? ? "[#{string}]" : '') +
                           (!accounts.empty? ? " [#{accounts}]" : '') +
                           (!model.empty? ? "[#{model}]" : '') +
                           (!firmware.empty? ? "[#{firmware}]" : '') +
                           (!filepath.empty? ? "[#{filepath}]" : '') +
                           (!modules.empty? ? "[#{modules}]" : '')
        end
      end
  
      status_code = HTTP_Status.code(status)
  
      if (@f == STDOUT && $use_colour == 'auto') || ($use_colour == 'always')
        brief_results_final = "#{blue(target)} [#{status} #{status_code}] #{brief_results.join(', ')}"
      else
        brief_results_final = "#{target} [#{status} #{status_code}] #{brief_results.join(', ')}"
      end
      $semaphore.synchronize do
        @f.puts brief_results_final
      end
    end
  end