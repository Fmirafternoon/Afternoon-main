class RecruitmentOffice::GeocodeLocationJob
  include Sidekiq::Job

  def perform(recruitment_office_id)
    office = RecruitmentOffice.find(recruitment_office_id)
    return if office.full_address.blank?

    result = Location::Geocode.result(address: office.full_address)
    return if result.location.blank?

    office.update(location_id: result.location.id)
  end
end
