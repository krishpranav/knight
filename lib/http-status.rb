module HTTP_Status
    def self.code(number)
        number = number.to_s

        abort('HTTP_STATUS must be initialized') unless @status_codes

        if @status_codes[number]
            @status_codes[number]
        else
            'Unassigned'
        end
    end

    def self.initialize
        @status_code = {}

        text.scan(/^([0-9]+),([^,]+)/).each do |k, v|
            @status_codes[k] = v
        end
    end
end

