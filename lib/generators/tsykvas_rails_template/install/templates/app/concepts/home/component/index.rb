# frozen_string_literal: true

class Home::Component::Index < ::Base::Component::Base
  def initialize(message:)
    @message = message
  end

  private

  attr_reader :message
end
