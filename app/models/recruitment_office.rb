class RecruitmentOffice < ApplicationRecord
  has_many :agents, class_name: "User", foreign_key: "recruitment_office_id"
  has_many :candidates, through: :agents
  has_many :partner_companies
  has_many :companies, through: :partner_companies
  belongs_to :location, optional: true

  validates :name, presence: true

  scope :kept, -> { where(discarded_at: nil) }
  scope :near_location, ->(lat, lng, radius_km = 50) {
    nearby_location_ids = Location.near([lat, lng], radius_km, units: :km).reorder(nil).pluck(:id)
    where(location_id: nearby_location_ids)
  }

  # La condition vit dans la méthode (et non en option if:) pour que les specs
  # puissent désactiver/réactiver le callback sans la perdre (cf. spec/support/disable_callbacks.rb)
  after_commit :enqueue_geocoding

  def full_address
    [address, zip_code, city].compact_blank.join(", ")
  end

  private

  def saved_change_to_geocodable_address?
    saved_change_to_address? || saved_change_to_zip_code? || saved_change_to_city?
  end

  def enqueue_geocoding
    return unless saved_change_to_geocodable_address?

    RecruitmentOffice::GeocodeLocationJob.perform_async(id)
  end
end
