class BasketPolicy < ApplicationPolicy
  def show?
    user.customer? && record.customer_id == user.id
  end

  def add_candidate?
    user.customer?
  end

  def remove_candidate?
    user.customer? && record.customer_id == user.id
  end

  def request_meeting?
    user.customer? && record.customer_id == user.id
  end

  def send_meeting_request?
    user.customer? && record.customer_id == user.id
  end
end
