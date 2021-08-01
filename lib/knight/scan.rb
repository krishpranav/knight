module WhatWeb
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

      # initialize target_queue
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

