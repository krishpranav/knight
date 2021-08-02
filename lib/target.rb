def open_target(url)
    newtarget = Target.new(url)
    begin
      newtarget.open
    rescue StandardError => err
      error("ERROR Opening: #{newtarget} - #{err}")
    end
    [newtarget.status, newtarget.uri, newtarget.ip, newtarget.body, newtarget.headers, newtarget.raw_headers]
  end
  
  def decode_html_entities(s)
    html_entities = { '&quot;' => '"', '&apos;' => "'", '&amp;' => '&', '&lt;' => '<', '&gt;' => '>' }
    s.gsub( /#{html_entities.keys.join("|")}/, html_entities)
  end
  

  def make_tag_pattern(b)

    inscript = false
  
    b.scan(/<([^\s>]*)/).flatten.map do |x|
      x.downcase!
      r = nil
      r = x if inscript == false
      inscript = true if x == 'script'
      (inscript = false; r = x) if x == '/script'
      r
    end.compact.join(',')
  end
  
  def randstr
    rand(36**8).to_s(36)
  end
  
  def match_ghdb(ghdb, body, _meta, _status, base_uri)
  
    pp 'match_ghdb', ghdb if $verbose > 2
  
    matches = [] 
    s = ghdb
  
    if s =~ /intitle:/i
      intitle = (s.scan(/intitle:"([^"]*)"/i) + s.scan(/intitle:([^"]\w+)/i)).to_s
      matches << ((body =~ /<title>[^<]*#{Regexp.escape(intitle)}[^<]*<\/title>/i).nil? ? false : true)

      s = s.gsub(/intitle:"([^"]*)"/i, '').gsub(/intitle:([^"]\w+)/i, '')
    end
  
    if s =~ /filetype:/i
      filetype = (s.scan(/filetype:"([^"]*)"/i) + s.scan(/filetype:([^"]\w+)/i)).to_s

      unless base_uri.nil?
        unless base_uri.path.split('?')[0].nil?
          matches << ((base_uri.path.split('?')[0] =~ /#{Regexp.escape(filetype)}$/i).nil? ? false : true)
        end
      end
      s = s.gsub(/filetype:"([^"]*)"/i, '').gsub(/filetype:([^"]\w+)/i, '')
    end
  
    if s =~ /inurl:/i
      inurl = (s.scan(/inurl:"([^"]*)"/i) + s.scan(/inurl:([^"]\w+)/i)).flatten

      inurl.each { |x| matches << ((base_uri.to_s =~ /#{Regexp.escape(x)}/i).nil? ? false : true) }
      
      s = s.gsub(/inurl:"([^"]*)"/i, '').gsub(/inurl:([^"]\w+)/i, '')
    end
  
  
    remaining_words = s.scan(/([^ "]+)|("[^"]+")/i).flatten.compact.each { |w| w.delete!('"') }.sort.uniq
  
    pp 'Remaining GHDB words', remaining_words if $verbose > 2
  
    remaining_words.each do |w|
      
      if w[0..0] == '-'

        matches << ((body =~ /#{Regexp.escape(w[1..-1])}/i).nil? ? true : false)
      else
        w = w[1..-1] if w[0..0] == '+' 
        matches << ((body =~ /#{Regexp.escape(w)}/i).nil? ? false : true)
      end
    end
  
    pp matches if $verbose > 2
  
    if matches.uniq == [true]
      true
    else
      false
    end
  end
  
  class Target
    include Helper
    attr_reader :target
    attr_reader :uri, :status, :ip, :body, :headers, :raw_headers, :raw_response
    attr_reader :cookies
    attr_reader :md5sum
    attr_reader :tag_pattern
    attr_reader :is_url, :is_file
    attr_accessor :http_options
    attr_reader :redirect_counter
  
    @@meta_refresh_regex = /<meta[\s]+http\-equiv[\s]*=[\s]*['"]?refresh['"]?[^>]+content[\s]*=[^>]*[0-9]+;[\s]*url=['"]?([^"'>]+)['"]?[^>]*>/i
  
    def pretty_print

      "URI\n#{'*' * 40}\n#{@uri}\n" \
        "status\n#{'*' * 40}\n#{@status}\n" \
        "ip\n#{'*' * 40}\n#{@ip}\n" \
        "redirects\n#{'*' * 40}\n#{@redirect_counter}\n" \
        "header\n#{'*' * 40}\n#{@headers}\n" \
        "cookies\n#{'*' * 40}\n#{@cookies}\n" \
        "raw_headers\n#{'*' * 40}\n#{@raw_headers}\n" \
        "raw_response\n#{'*' * 40}\n#{@raw_response}\n" \
        "body\n#{'*' * 40}\n#{@body}\n" \
        "md5sum\n#{'*' * 40}\n#{@md5sum}\n" \
        "tag_pattern\n#{'*' * 40}\n#{@tag_pattern}\n" \
        "is_url\n#{'*' * 40}\n#{@is_url}\n" \
        "is_file\n#{'*' * 40}\n#{@is_file}\n"
    end
  
    def to_s
      @target
    end
  
    def self.meta_refresh_regex
      @@meta_refresh_regex
    end
  
    def is_file?
      @is_file
    end
  
    def is_url?
      @is_url
    end
  
    def initialize(target = nil, redirect_counter = 0)
      @target = target
      @redirect_counter = redirect_counter
      @headers = {}
      @http_options = { method: 'GET' }
  
      @is_url = if @target =~ /^http[s]?:\/\//
                  true
                else
                  false
                end
  
      if File.exist?(@target)
        @is_file = true
        raise "Error: #{@target} is a directory" if File.directory?(@target)
        if File.readable?(@target) == false
          raise "Error: You do not have permission to view #{@target}"
        end
      else
        @is_file = false
      end
  
      if is_url?
        @uri = URI.parse(Addressable::URI.encode(@target))
  
        @uri.path = '/' if @uri.path.empty?
      else

        @uri = URI.parse('')
      end
    end
  
    def open
      if is_file?
        open_file
      else
        open_url(@http_options)
      end
  
      sleep $WAIT if $WAIT
  
      if @body.nil?

        @body = ''
      else
        @md5sum = Digest::MD5.hexdigest(@body)
        @tag_pattern = make_tag_pattern(@body)
        if @raw_headers
          @raw_response = @raw_headers + @body
        else
          @raw_response = @body
          @raw_headers = ''
          @cookies = []
        end
      end
    end
  
    def open_file
      @body = File.open(@target).read
  
      @body = @body.encode('UTF-16', 'UTF-8', invalid: :replace, replace: '').encode('UTF-8')

      if @body =~ /^HTTP\/1\.\d [\d]{3} (.+)\r\n\r\n/m

        @headers = {}
        pageheaders = body.to_s.split(/\r\n\r\n/).first.to_s.split(/\r\n/)
        @raw_headers = pageheaders.join("\n") + "\r\n\r\n"
        @status = pageheaders.first.scan(/^HTTP\/1\.\d ([\d]{3}) /).flatten.first.to_i
        @cookies = []
        for k in 1...pageheaders.length
          section = pageheaders[k].split(/:/).first.to_s.downcase
          if section =~ /^set-cookie$/i
            @cookies << pageheaders[k].scan(/:[\s]*(.+)$/).flatten.first
          else
            @headers[section] = pageheaders[k].scan(/:[\s]*(.+)$/).flatten.first
          end
        end
        @headers['set-cookie'] = @cookies.join("\n") unless @cookies.nil? || @cookies.empty?
        if @body =~ /^HTTP\/1\.\d [\d]{3} .+?\r\n\r\n(.+)/m
          @body = @body.scan(/^HTTP\/1\.\d [\d]{3} .+?\r\n\r\n(.+)/m).flatten.first
        end
      end
    rescue StandardError => err
      raise err
    end
  
    def open_url(options)
      begin
        @ip = Resolv.getaddress(@uri.host)
      rescue StandardError => err
        raise err
      end
  
      begin
        if $USE_PROXY == true
          http = ExtendedHTTP::Proxy($PROXY_HOST, $PROXY_PORT, $PROXY_USER, $PROXY_PASS).new(@uri.host, @uri.port)
        else
          http = ExtendedHTTP.new(@uri.host, @uri.port)
        end
  
        http.open_timeout = $HTTP_OPEN_TIMEOUT
        http.read_timeout = $HTTP_READ_TIMEOUT
  
        if @uri.class == URI::HTTPS
          http.use_ssl = true
          OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:ciphers] = 'TLSv1:TLSv1.1:TLSv1.2:SSLv3:SSLv2'
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
  
        getthis = @uri.path + (@uri.query.nil? ? '' : '?' + @uri.query)
        req = nil
  
        if options[:method] == 'GET'
          req = ExtendedHTTP::Get.new(getthis, $CUSTOM_HEADERS)
        end
        if options[:method] == 'HEAD'
          req = ExtendedHTTP::Head.new(getthis, $CUSTOM_HEADERS)
        end
        if options[:method] == 'POST'
          req = ExtendedHTTP::Post.new(getthis, $CUSTOM_HEADERS)
          req.set_form_data(options[:data])
        end
  
        req.basic_auth $BASIC_AUTH_USER, $BASIC_AUTH_PASS if $BASIC_AUTH_USER
  
        res = http.request(req)
        @raw_headers = http.raw.join("\n")
        @headers = {}
  
        @body = res.body
        
        @body = Helper::convert_to_utf8(@body)
        @raw_headers = Helper::convert_to_utf8(@raw_headers)
  
        res.each_header do |x, y| 
          newx, newy = x.dup, y.dup
          @headers[ Helper::convert_to_utf8(newx) ] = Helper::convert_to_utf8(newy)
        end
  
        @headers['set-cookie'] = res.get_fields('set-cookie').join("\n") unless @headers['set-cookie'].nil?
  
        @status = res.code.to_i
        puts @uri.to_s + " [#{status}]" if $verbose > 1
  
      rescue StandardError => err
        raise err
  
      end
    end
  
  
    def get_redirection_target
      newtarget_m, newtarget_h, newtarget = nil
  
      if @@meta_refresh_regex =~ @body
        metarefresh = @body.scan(@@meta_refresh_regex).flatten.first
        metarefresh = decode_html_entities(metarefresh).strip
        newtarget_m = URI.join(@target, metarefresh).to_s 
      end
  
      if (300..399) === @status && @headers && @headers['location']
  
        location = @headers['location']
        begin
          newtarget_h = URI.join(@target, location).to_s
        rescue StandardError => err
          error("Error: Invalid redirection from #{@target} to #{location}. #{err}")
          return nil
        end
  
      end
  
      if newtarget_m || newtarget_h
        case $FOLLOW_REDIRECT
        when 'never'

        when 'http-only'
          newtarget = newtarget_h
        when 'meta-only'
          newtarget = newtarget_m
        when 'same-site'
          newtarget = (newtarget_h || newtarget_m) if URI.parse((newtarget_h || newtarget_m)).host == @uri.host 
        when 'always'
          newtarget = (newtarget_h || newtarget_m)
        else
          error('Error: Invalid REDIRECT mode')
        end
      end
      newtarget = nil if newtarget == @uri.to_s 
  
      newtarget
    end
  end