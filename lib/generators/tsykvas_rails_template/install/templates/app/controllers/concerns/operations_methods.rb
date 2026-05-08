# frozen_string_literal: true

module OperationsMethods
  include ActionView::Helpers::JavaScriptHelper
  extend ActiveSupport::Concern

  protected

  def endpoint(operation, component = nil, &block)
    result = operation.call(params:, current_user: try(:current_user))

    check_authorization_is_called result

    # Call custom block if provided (useful for Devise sign-in, etc.)
    block.call(result) if block_given?

    respond_to do |format|
      format.html do
        if action_name == "create" || action_name == "update" || action_name.include?("destroy")
          if result.success? || (result.failure? && action_name.include?("destroy"))
            flash[:notice] = result.message if result.message.present?
            flash[:alert] = result.error_message if result.error_message.present?
            path = result.redirect_path || public_send("#{controller_name}_path")
            redirect_to path
          else
            flash[:alert] = result.error_message if result.error_message.present?
            params = if result.model.is_a?(::OpenStruct)
                       result.model.to_h
                     else
                       key = operation.to_s.split("::").first.underscore
                       { "#{key}": result.model }
                     end

            render component.new(**params), status: :unprocessable_content
          end
        elsif action_name == "index"
          flash[:notice] = result.message if result.message.present?
          flash[:alert] = result.error_message if result.error_message.present?
          params = if result.model.is_a?(::OpenStruct)
                     result.model.to_h
                   else
                     key = operation.to_s.split("::").first.underscore.pluralize
                     { "#{key}": result.model }
                   end

          render component.new(**params)
        elsif action_name == "show"
          flash[:notice] = result.message if result.message.present?
          flash[:alert] = result.error_message if result.error_message.present?
          params = if result.model.is_a?(::OpenStruct)
                     result.model.to_h
                   else
                     key = operation.to_s.split("::").first.underscore
                     { "#{key}": result.model }
                   end

          render component.new(**params)
        elsif action_name == "edit" || action_name == "new"
          flash[:notice] = result.message if result.message.present?
          flash[:alert] = result.error_message if result.error_message.present?
          params = if result.model.is_a?(::OpenStruct)
                     result.model.to_h
                   else
                     key = operation.to_s.split("::").first.underscore
                     { "#{key}": result.model }
                   end

          render component.new(**params)
        end
      end

      # Used for rendering new/edit modals via JS.
      #
      # Assumes Bootstrap modals are available globally as `window.bootstrap.Modal`.
      # If your app uses a different modal library (or none), the inline JS below
      # gracefully no-ops on the dismiss step. Replace this branch entirely if
      # you ship your own modal stack.
      format.js do
        params = if result.model.is_a?(::OpenStruct)
                   result.model.to_h
                 else
                   key = operation.to_s.split("::").first.underscore
                   { "#{key}": result.model }
                 end

        if result.success? && (action_name == "create" || action_name == "update" || action_name.include?("destroy"))
          flash[:notice] = result.message if result.message.present?
          flash[:alert] = result.error_message if result.error_message.present?
          path = result.redirect_path || public_send("#{controller_name}_path")
          render js: "window.location.href='#{path}'"
        else
          modal = render_to_string(component.new(**params), layout: false)
          render js: <<~JS
            var activeModal = document.querySelector('.modal.show');
            if (activeModal && window.bootstrap && window.bootstrap.Modal) {
                window.bootstrap.Modal.getOrCreateInstance(activeModal).hide();
            }
            var modalsContainer = document.getElementById('modals');
            if (modalsContainer) {
                modalsContainer.innerHTML = "";
                var renderedHtml = "#{escape_javascript(modal)}";
                var tempContainer = document.createElement("div");
                tempContainer.innerHTML = renderedHtml;
                if (tempContainer.firstElementChild) {
                    modalsContainer.appendChild(tempContainer.firstElementChild);
                }
            }
          JS
        end
      end

      # Used for select2 search results.
      format.json do
        collection = if result.model.is_a?(::OpenStruct)
                       key = operation.to_s.split("::").first.underscore.pluralize
                       result.model[key]
                     else
                       result.model
                     end
        render json: {
          result: collection.map(&:select2_search_result),
          pagination: {
            more: collection.respond_to?(:next_page) && collection.next_page.present?
          }
        }
      end

      # Fallback for auto-submit controllers that send null requests.
      format.any do
        flash[:notice] = result.message if result.message.present?
        flash[:alert] = result.error_message if result.error_message.present?
        params = if result.model.is_a?(::OpenStruct)
                   result.model.to_h
                 else
                   key = operation.to_s.split("::").first.underscore.pluralize
                   { "#{key}": result.model }
                 end
        render component.new(**params)
      end
    end
  end

  def check_authorization_is_called(result)
    skip_authorization if result[:pundit] || result["policy.run"] || result.failure?
    skip_policy_scope if result[:pundit_scope] || result.failure?
    result[:model]
  end
end
