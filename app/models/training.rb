class Training < ApplicationRecord
  belongs_to :candidate, touch: true

  default_scope { order(year: :desc) }
end
