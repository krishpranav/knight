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