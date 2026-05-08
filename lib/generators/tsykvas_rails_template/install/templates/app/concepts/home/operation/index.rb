# frozen_string_literal: true

require "ostruct"

# Canonical example operation. Replace with real logic when the home page
# becomes more than a placeholder. Demonstrates the three required calls:
# `authorize!`, `skip_policy_scope`, and assigning `self.model`.
class Home::Operation::Index < ::Base::Operation::Base
  def perform!(params:, current_user:)
    authorize! :home, :index?
    skip_policy_scope

    self.model = OpenStruct.new(
      message: "Welcome — your app is wired up with tsykvas_rails_template."
    )
  end
end
