class Candidate::GeocodeLocationJob
  include Sidekiq::Job

  def perform(candidate_id)
    candidate = Candidate.find(candidate_id)
    return if candidate.address.blank?

    result = Location::Geocode.result(address: candidate.address)
    candidate.update(location_id: result.location.id)
  end
end
