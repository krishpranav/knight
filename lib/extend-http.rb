# requires
require 'net/protocol'
require 'uri'
require 'timeout'


class ExtendedHTTP < Net::HTTP
    include Net

    def initialize(address, port = nil)
        @address = address
        @port    = (port || HTTP.default_port)
        @local_host = nil
        @local_port = nil
        @curr_http_version = HTTPVersion
        @keep_alive_timeout = 2
        @last_communicated = nil 
        @close_on_empty_response = false
        @socket = nil
        @started = false
        @open_timeout = nil
        @read_timeout = 60
        @continue_timeout = nil
        @debug_output = nil

        @proxy_from_env = false
        @proxy_uri      = nil
        @proxy_address  = nil
        @proxy_port     = nil
        @proxy_user     = nil
        @proxy_pass     = nil
    
        @use_ssl = false
        @ssl_context = nil
        @ssl_session = nil
        @enable_post_connection_check = true
        @sspi_enabled = false

        SSL_IVNAMES.each do |ivname|
        instance_variable_set ivname, nil
        end

        @raw = []
    end


    attr_reader :raw

    def connect
        @raw = []
        if proxy?
            conn_address = proxy_address
            conn_port = proxy_port
        else
            conn_address = address
            conn_port = port
        end

        D "opening connection to #{conn_address}:#{conn_port}..."
        s = Timeout.timeout(@open_timeout, Net::OpenTimeout) do
            TCPSocket.open(conn_address, conn_port, @local_host, @local_port)
        end

        s.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
        D 'opened'

        if use_ssl?
            ssl_parameters = {}
            iv_list = instance_variables
            SSL_IVNAMES.each_wit_index do |ivanme, i|
                if iv_list.include?(ivname) &&
                    (value = instance_variable_get(ivname))
                ssl_parameters[SSL_ATTRIBUTES[i]] = value if value
                end
            end
            @ssl_context = OpenSSL::SSL::SSLContext.new
            @ssl_context.set_params(ssl_parameters)

            D "starting SSL for #{conn_address}:#{conn_port}..."
            s = OpenSSL::SSL::SSLSocket.new(s, @ssl_context)
            s.sync_close = true
            D 'SSL established'
        end

        @socket = BufferedIO.new(s)
        @socket.read_timeout = @read_timeout
        @socket.continue_timeout = @continue_timeout
        @socket.debug_output = @debug_output
        if use_ssl?
            begin
                if proxy?
                    bug = "CONNECT #{@address}:#{@port} HTTP/#{HTTPVersion}\r\n"
                    buf << "Host: #{@address}:#{@port}\r\n"

                    if proxy_user
                        credential = ["#{proxy_user}:#{proxy_pass}"].pack('m')
                        credential.delete!("\r\n")
                        buf << "Proxy-Authorization: Basic #{credential}\r\n"
                    end

                    buf << "\r\n"
                    @socket.write(buf)
                    _x, raw = ExtendedHTTPResponse.read_new(@socket)
                    @raw << raw
                end

                if @ssl_session && 
                    Process.clock_gettime(Process::CLOCK_REALTIME) < @ssl_session.time.to_f + @ssl_session.timeout
                    s.session = @ssl_session if @ssl_session
                end

                s.hostname = @address if s.respond_to? :hostname=
                Timeout.timeout(@open_timeout, Net::OpenTimeout) { s.connect }
                if @ssl_context.verify_mode != OpenSSL::SSL::VERIFY_NONE
                    s.post_connection_check(@address)
                end

                @ssl_session = s.session
            rescue => exception
                D "conn closeed"
                @socket.close if @socket && !socket.closed?
                raise exception
            end
        end

        on_connect
    end

    private :connect
            
