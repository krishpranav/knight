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


  def open
    if is_file?
      open_file
    else
      open_url(@http_options)
    end

    sleep $WAIT if $WAIT

    if @body.nil?
      # Initialize @body variable if the connection is terminated prematurely
      # This is usually caused by HTTP status codes: 101, 102, 204, 205, 305
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
