module Knight
  class Scan
    def initialize(urls, input_file: nil, url_prefix: nil, url_suffix: nil, url_pattern: nil, max_threads: 25)
      urls = [urls] if urls.is_a?(String)

      @targets = make_target_list(
        urls,
        input_file: input_file,
        url_prefix: url_prefix,
        url_suffix: url_suffix,
        url_pattern: url_pattern
      )

      error('No targets selected') if @targets.empty?

      @max_threads = max_threads.to_i || 25
      @target_queue = Queue.new 
    end

    def scan
      Thread.abort_on_exception = true if $WWDEBUG

      workers = (1..@max_threads).map do
        Thread.new do
          loop do
            target = @target_queue.pop
            Thread.exit unless target

            begin
              target.open
            rescue => e
              error("ERROR Opening: #{target} - #{e}")
              target = nil 
              next
            end

            yield target
          end
        end
      end

      @targets.each do |url|
        target = prepare_target(url)
        next unless target
        @target_queue << target
      end

      loop do

        alive = workers.map { |worker| worker if worker.alive? }.compact.length
        break if alive == @target_queue.num_waiting && @target_queue.empty?
      end

      (1..@max_threads).each { @target_queue << nil }
      workers.each(&:join)
    end

    def scan_from_plugin(target: nil)
      raise 'No target' unless target

      begin
        target.open
      rescue => e
        error("ERROR Opening: #{target} - #{e}")
      end
      target
    end

    def add_target(url, redirect_counter = 0)

      target = Target.new(url, redirect_counter)

      unless target
        error("Add Target Failed - #{url}")
        return
      end

      @target_queue << target
    end

    private

    def prepare_target(url)
      Target.new(url)
    rescue => e
      error("Prepare Target Failed - #{e}")
      nil
    end

    def make_target_list(urls, opts = {})
      url_list = []

      if urls.is_a?(Array)
        urls.flatten.reject { |u| u.nil? }.map { |u| u.strip }.reject { |u| u.eql?('') }.each do |url|
          url_list << url
        end
      end

      inputfile = opts[:input_file] || nil
      if !inputfile.nil? && File.exist?(inputfile)
        pp "loading input file: #{inputfile}" if $verbose > 2
        File.open(inputfile).readlines.each(&:strip!).reject { |line| line.start_with?('#') || line.eql?('') }.each do |line|
          url_list << line
        end
      end

      return [] if url_list.empty?

      ip_range = url_list.map do |x|
        range = nil
        if x =~ %r{^[0-9\.\-\/]+$} && x !~ %r{^[\d\.]+$}
          begin

            if x =~ %r{\d+\.\d+\.\d+\.\d+/\d+$}
              range = IPAddr.new(x).to_range.map(&:to_s)
            elsif x =~ %r{^(\d+\.\d+\.\d+\.\d+)-(\d+)$}
              start_ip = IPAddr.new(Regexp.last_match(1), Socket::AF_INET)
              end_ip   = IPAddr.new("#{start_ip.to_s.split('.')[0..2].join('.')}.#{Regexp.last_match(2)}", Socket::AF_INET)
              range = (start_ip..end_ip).map(&:to_s)

            elsif x =~ %r{^(\d+\.\d+\.\d+\.\d+)-(\d+\.\d+\.\d+\.\d+)$}
              start_ip = IPAddr.new(Regexp.last_match(1), Socket::AF_INET)
              end_ip   = IPAddr.new(Regexp.last_match(2), Socket::AF_INET)
              range = (start_ip..end_ip).map(&:to_s)
            end
          rescue => e

            raise "Error parsing target IP range: #{e}"
          end
        end
        range
      end.compact.flatten

      url_list = url_list.select { |x| !(x =~ %r{^[0-9\.\-*\/]+$}) || x =~ /^[\d\.]+$/ }
      url_list += ip_range unless ip_range.empty?

      push_to_urllist = []

      url_list = url_list.map do |x|
        if File.exist?(x)
          x
        else
          x = opts[:url_pattern].gsub('%insert%', x) unless opts[:url_pattern].to_s.eql?('')
          x = "#{opts[:url_prefix]}#{x}#{opts[:url_suffix]}"

          if x !~ %r{^[a-z]+:\/\/}

            x.sub!(/^/, 'http://')
          end

          begin
            domain = Addressable::URI.parse(x)
            raise 'Unable to parse invalid target. No hostname.' if domain.host.empty?

            x = domain.normalize.to_s if domain.host !~ %r{^[a-zA-Z0-9\.:\/]*$}
          rescue => e

            x = nil
            error("Unable to parse invalid target #{x}: #{e}")
          end
          x
        end
      end

      url_list += push_to_urllist unless push_to_urllist.empty?

      url_list = url_list.flatten.compact 
    end
  end
end