# frozen_string_literal: true

# Canonical example policy paired with Home::Operation::Index. The home
# page is public, so `index?` returns true unconditionally. Replace with
# real authorization rules when the home page is no longer a placeholder.
class HomePolicy < ApplicationPolicy
  def index? = true
end
