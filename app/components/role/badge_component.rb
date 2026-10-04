class Role::BadgeComponent < BadgeComponent
  def initialize(role:)
    @role = role
    nil unless @role.present?
  end

  def render?
    @role.present?
  end

  def label
    User.human_enum_name(:role, @role)
  end

  def classes
    colors = {
      super_admin: "bg-red-100 text-red-800",
      agent_manager: "bg-purple-100 text-purple-800",
      agent_user: "bg-blue-100 text-blue-800",
      customer: "bg-green-100 text-green-800"
    }
    colors[@role.to_sym] || "bg-gray-100"
  end
end
