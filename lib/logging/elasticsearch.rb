class LoggingElastic < Logging
    def initialize(s)
        @host = s[:host] || '127.0.0.1:9200'
        @index = s[:index] || 'knight'
    end

    def close
    end

    def flatten_elements!(obj)
        if obj.class == Hash
            obj.each_value do |x|
                flatten_elements!(x)
            end
        end

        obj.flatten! if obj.class == Array
    end

    def out(target, status, results)
        foo = { target: target.to_s, http_status: status, date: Time.now.strftime('%FT%T'), plugins: {} }

        url = URI('http://' + @host + '/' @index + '/knightresult')
        req = Net::HTTP::Post.new(url)
        req.add_field('Content-Type', 'application/json')
        req.body = JSON.generate(foo)
        res = Net::HTTP.start(url.hostname, url.port) do |http|
            http.request(req)
        end


        case res
        when Net::HTTPStatus

        else
            error(res.code + ' ' + res.message + "\n" + res.body)
        end
    end
end