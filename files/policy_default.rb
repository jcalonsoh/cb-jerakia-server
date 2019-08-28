policy :default do
  lookup :main do
    datasource :file, {
      format:     :yaml,
      docroot:    '/var/db/jerakia',
      searchpath: [
        "hostname/#{scope[:certname]}",
        "environment/#{scope[:environment]}",
        "location/#{scope[:location]}",
        'common'
      ]
    }
  end
end
