# frozen_string_literal: true

require "pundit"

class Base::Operation::Base
  attr_accessor :result

  def self.call(**args)
    ops = new(**args).tap(&:call)
    ops.result
  end

  def initialize(**attrs)
    @attrs = attrs
    @result = ::Base::Operation::Result.new
  end

  def call
    perform!(**@attrs)
    copy_errors_from_result_to_model
    @result
  rescue ActiveRecord::RecordInvalid => e
    add_errors e.record&.errors
    copy_errors_from_result_to_model
    @result
  end

  private

  def copy_errors_from_result_to_model
    return if model.nil? || !model.respond_to?(:errors)

    result.errors[:base].each do |message|
      model.errors.add(:base, message) unless model.errors[:base].include?(message)
    end
  end

  def notice(text, level: :notice)
    @result[:notice] = {
      text:,
      level:
    }
  end

  def redirect_path=(path)
    @result[:redirect_path] = path
  end

  def redirect_path
    @result[:redirect_path]
  end

  def model=(model)
    @result[:model] = model
  end

  def model
    @result[:model]
  end

  def add_error(key, message)
    @result.errors.add :base, key, message:
  end

  def add_errors(from)
    return if from.nil?

    from.each do |error|
      from[error.attribute].each do |error_msg|
        @result.errors.add(error.attribute, error_msg)
      end
    end
  end

  def invalid!
    @result.invalid!
  end

  ### Run sub operations ###

  def run_operation(operation_class, parameters)
    manually_handle_errors = parameters[:manually_handle_errors].present?
    parameters.except!(:manually_handle_errors)
    run_result = operation_class.new(**parameters).tap(&:call).result
    result.sub_results << run_result
    if !manually_handle_errors && run_result.present? && run_result.failure?
      add_errors run_result.errors
      raise ActiveRecord::RecordInvalid
    end
    run_result
  end

  ### Authorization methods ###

  def authorize!(record, query, policy: Pundit.policy!(@attrs[:current_user], record), fail_message: nil)
    if policy.public_send(query)
      @result[:pundit] = true
      return
    end

    raise Pundit::NotAuthorizedError, fail_message if fail_message.present?

    raise Pundit::NotAuthorizedError, query:, record:, policy:
  end

  def policy_scope(scope)
    @result[:pundit_scope] = true
    Pundit.policy_scope!(@attrs[:current_user], scope)
  end

  def skip_authorize
    @result[:pundit] = true
  end

  def skip_policy_scope
    @result[:pundit_scope] = true
  end

  def authorize_and_save!(auth_method = nil)
    auth_method ||= model.new_record? ? :create? : :update?
    authorize! model, auth_method
    model.save!
  end
end
