class BasketItemPolicy < ApplicationPolicy
  def calendar?
    user.customer? && record.basket.customer_id == user.id
  end
end
