module ActiveAdmin
  class SkillPolicy < ApplicationPolicy
    def edit?
      user&.super_admin?
    end

    def update?
      user&.super_admin?
    end

    def generate_semantic?
      user&.super_admin?
    end

    def generate_embedding?
      user&.super_admin?
    end

    def backfill_semantic?
      user&.super_admin?
    end

    def backfill_embedding?
      user&.super_admin?
    end
  end
end
