Plugin.define do
    name "360-Web-Manager"
    authors [
      "Krisna Pranav ",
    ]
    version "0.2"
    description "360-Web-Manager"
    website "http://www.360webmanager.com"
    
    # About 36,800 results for "powered by 360 Web Manager" @ 2010-06-12
    
    matches [
    
    # Powered by text
    { :ghdb=>'"powered by 360 Web Manager"', :certainty=>75 },
    
    # Redirect page
    { :regexp=>/360WebManager Software :: administrador contenidos web/, :certainty=>75 },
    
    # Version detection # Powered by text
    { :version=>/<div align="center"><span class="copyr">Powered by <a href="http:\/\/www.360webmanager.com" target="_blank" class="copyrlink">360 Web Manager<\/a> ([\d\.]+)/ },
    
    ]
    
    end
    