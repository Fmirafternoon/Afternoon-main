class User::AvatarComponent < ViewComponent::Base
  def initialize(user:, size: :normal)
    @user = user
    @size = size
  end

  attr_reader :user, :size

  def size_classes
    case size
    when :sm
      "w-8 h-8 text-sm"
    else # :normal
      "w-15 h-15 text-lg"
    end
  end

  def initials
    "#{user.first_name.first}#{user.last_name.first}".upcase
  end
end
