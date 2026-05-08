# frozen_string_literal: true

class Base::Operation::Result
  include ActiveModel::Validations

  def initialize
    @attrs = {}
    @forced_invalid = false
  end

  delegate :[], :[]=, :fetch, to: :@attrs

  def model
    @attrs[:model]
  end

  def redirect_path
    @attrs[:redirect_path]
  end

  def sub_results
    @attrs[:sub_results] ||= []
  end

  def success?
    return false unless !@forced_invalid && errors.empty?
    return false unless model.nil? || !model.respond_to?(:errors) ? true : model.errors.empty?

    sub_results.all?(&:success?)
  end

  def failure?
    !success?
  end

  def invalid!
    @forced_invalid = true
  end

  def error_message
    errors[:base].join(" ")
  end

  def all_error_messages
    errors.map(&:message)
  end

  # Translated message for use in flash notices and alerts.
  def message
    @attrs.dig(:notice, :text)
  end

  def message_level
    @attrs.dig(:notice, :level)
  end
end
