class Plugin
    class << self
      attr_reader :registered_plugins, :attributes
      private :new
    end
  
    @registered_plugins = {}
    @attributes = %i(
      aggressive
      authors
      description
      dorks
      matches
      name
      passive
      version
      website
    )
  
    @attributes.each do |symbol|
      define_method(symbol) do |*value, &block|
        name = "@#{symbol}"
        if block
          instance_variable_set(name, block)
        elsif !value.empty?
          instance_variable_set(name, *value)
        else
          instance_variable_get(name)
        end
      end
    end
  
    def initialize
      @matches = []
      @dorks = []
      @passive = nil
      @aggressive = nil
      @variables = {}
      @website = nil
    end
  
    def self.define(&block)
      p = new
      p.instance_eval(&block)
      p.startup

      Plugin.attributes.each { |symbol| p.instance_variable_get("@#{symbol}").freeze }
      Plugin.registered_plugins[p.name] = p
    end
  
    def self.shutdown_all
      Plugin.registered_plugins.each { |_, plugin| plugin.shutdown }
    end
  
    def version_detection?
      return false unless @matches
      !@matches.map { |m| m[:version] }.compact.empty?
    end
  
    def startup; end
  
    def shutdown; end
  
    def scan(target)
      scan_context = ScanContext.new(plugin: self, target: target, scanner: nil)
      scan_context.instance_variable_set(:@variables, @variables)
      scan_context.x
    end
  end
  
  class ScanContext
    def initialize(plugin: nil, target: nil, scanner: nil)
      @plugin = plugin
      @matches = plugin.matches
      define_singleton_method(:passive_scan, plugin.passive) if plugin.passive
      define_singleton_method(:aggressive_scan, plugin.aggressive) if plugin.aggressive
      @target = target
      @body = target.body
      @headers = target.headers
      @status = target.status
      @base_uri = target.uri
      @md5sum = target.md5sum
      @tagpattern = target.tag_pattern
      @ip = target.ip
      @raw_response = target.raw_response
      @raw_headers = target.raw_headers
      @scanner = scanner
    end
  
    def make_matches(target, match)
      r = []
  
      search_context = target.body
      if match[:search]
        case match[:search]
        when 'all'
          search_context = target.raw_response
        when 'uri.path'
          search_context = target.uri.path
        when 'uri.query'
          search_context = target.uri.query
        when 'uri.extension'
          search_context = target.uri.path.scan(/\.(\w{3,6})$/).flatten.first
          return r if search_context.nil?
        when 'headers'
          search_context = target.raw_headers
        when /headers\[(.*)\]/
          header = Regexp.last_match(1).downcase
  
          if target.headers[header]
            search_context = target.headers[header]
          else

            return r
          end
        end
      end
  
      if match[:ghdb]
        r << match if match_ghdb(match[:ghdb], target.body, target.headers, target.status, target.uri)
      end
  
      if match[:text]
        r << match if match[:regexp_compiled] =~ search_context
      end
  
      if match[:md5]
        r << match if target.md5sum == match[:md5]
      end
  
      if match[:tagpattern]
        r << match if target.tag_pattern == match[:tagpattern]
      end
  
      if match[:regexp_compiled] && search_context
        [:regexp, :account, :version, :os, :module, :model, :string, :firmware, :filepath].each do |symbol|
          next unless match[symbol] && match[symbol].class == Regexp
          regexpmatch = search_context.scan(match[:regexp_compiled])
          next if regexpmatch.empty?
          m = match.dup
          m[symbol] = regexpmatch.map do |eachmatch|
            if eachmatch.is_a?(Array) && match[:offset]
              eachmatch[match[:offset]]
            elsif eachmatch.is_a?(Array)
              eachmatch.first
            elsif eachmatch.is_a?(String)
              eachmatch
            end
          end.flatten.compact.sort.uniq
          r << m
        end
      end
  
      return r if r.empty?

      url_matched = false
      status_matched = false
  
      if match[:status]
        status_matched = true if match[:status] == target.status
      end
  
      if match[:url]
  
        is_relative = if match[:url] =~ /^\//
                        false
                      else
                        true
                      end
  
        has_query = if match[:url] =~ /\?/
                      true
                    else
                      false
                    end
  
        if is_relative && !has_query
          url_matched = true if target.uri.path =~ /#{match[:url]}$/
        end
  
        if is_relative && has_query
          if target.uri.query
            url_matched = true if "#{target.uri.path}?#{target.uri.query}" =~ /#{match[:url]}$/
          end
        end
  
        if !is_relative && has_query
          if target.uri.query
            url_matched = true if "#{target.uri.path}?#{target.uri.query}" == match[:url]
          end
        end
  
        if !is_relative && !has_query
          url_matched = true if target.uri.path == match[:url]
        end
      end
  
      if match[:status] && match[:url]
        if url_matched && status_matched
          r << match
        else
          r = []
        end
      elsif match[:status] && match[:url].nil?
        if status_matched
          r << match
        else
          r = []
        end
      elsif !match[:status] && match[:url]
        if url_matched
          r << match
        else
          r = []
        end
      elsif !match[:status] && !match[:url]
      end
  
      r
    end
  
    def x
      results = []
      unless @matches.nil?
        @matches.each do |match|
          results += make_matches(@target, match)
        end
      end
  
      results += passive_scan if @plugin.passive
  
      if ($AGGRESSION == 3 && results.any?) || ($AGGRESSION == 4)
        results += aggressive_scan if @plugin.aggressive

        if @matches
          @matches.map { |x| x if x[:url] }.compact.sort_by { |x| x[:url] }.map do |match|
            newbase_uri = URI.join(@base_uri.to_s, match[:url]).to_s
  
            aggressivetarget = Target.new(newbase_uri)
            aggressivetarget.open

  
            results += make_matches(aggressivetarget, match)
          end
        end
      end

      unless results.empty?
        results.each do |r|
          r[:certainty] = 100 if r[:certainty].nil?
        end
      end
  
      results
    end
  end