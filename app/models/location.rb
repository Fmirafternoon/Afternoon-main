class Location < ApplicationRecord
  geocoded_by :full_address
  reverse_geocoded_by :latitude, :longitude

  has_many :company_locations, dependent: :destroy
  has_many :companies, through: :company_locations

  has_many :candidate_mobilities, dependent: :destroy
  has_many :candidates, through: :candidate_mobilities

  def name
    "#{city}, #{zip_code}"
  end

  def full_address
    if address.present? && address.strip.present?
      "#{address}, #{zip_code} #{city}"
    else
      "#{zip_code} #{city}"
    end
  end
end
