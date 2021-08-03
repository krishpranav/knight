class LoggingJSONVerbose < Logging
    def out(target, status, results)

      $semaphore.synchronize do
        @f.puts JSON.fast_generate([target, status, results])
      end
    end
  end