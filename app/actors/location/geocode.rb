class Location::Geocode < Actor
  input :address

  output :location

  def call
    url = URI("https://api-adresse.data.gouv.fr/search/?q=#{CGI.escape(address)}")
    https = Net::HTTP.new(url.host, url.port)
    https.use_ssl = true

    request = Net::HTTP::Get.new(url)
    response = JSON.parse(https.request(request).body)

    if response["features"].first.present?
      street = response["features"].first["properties"]["name"]
      city = response["features"].first["properties"]["city"]
      zip_code = response["features"].first["properties"]["postcode"]
      lat = response["features"].first["geometry"]["coordinates"][1]
      lng = response["features"].first["geometry"]["coordinates"][0]

      self.location = Location.find_or_create_by(
        address: street,
        city: city,
        zip_code: zip_code,
        latitude: lat,
        longitude: lng
      )
    end
  end
end
