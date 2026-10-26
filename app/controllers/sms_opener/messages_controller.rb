# frozen_string_literal: true

require "action_controller"
require "erb"
require "json"

module SmsOpener
  class MessagesController < ActionController::Base
    protect_from_forgery with: :null_session if respond_to?(:protect_from_forgery)

    def index
      @messages = SmsOpener.messages
      @selected_message = if params[:id]
                            SmsOpener.find(params[:id]) || @messages.first
                          else
                            @messages.first
                          end

      if json_request?
        render json: @messages.map(&:to_h)
      else
        render html: render_inbox_template.html_safe, layout: false
      end
    end

    def show
      @message = SmsOpener.find(params[:id])
      if @message.nil?
        if json_request?
          render json: { error: "Message not found" }, status: :not_found
        else
          render plain: "Message not found", status: :not_found
        end
        return
      end

      if json_request?
        render json: @message.to_h
      else
        html = File.exist?(@message.filepath) ? File.read(@message.filepath) : @message.rendered_html
        render html: html.html_safe, layout: false
      end
    end

    def create
      to = params[:to].to_s.strip
      from = params[:from].to_s.strip
      body = params[:body].to_s

      if to.empty? || body.empty?
        if json_request?
          render json: { error: "Both 'to' and 'body' are required" }, status: :unprocessable_entity
        else
          redirect_to root_path
        end
        return
      end

      message = SmsOpener::DeliveryMethod.new(launch_browser: false).deliver!(
        to: to,
        from: from.empty? ? nil : from,
        body: body,
        provider: params[:provider].presence || "web_test"
      )

      if json_request?
        render json: message.to_h, status: :created
      else
        redirect_to root_path(id: message.id)
      end
    end

    def destroy
      message = SmsOpener.find(params[:id])
      message&.delete!

      if json_request?
        head :no_content
      else
        redirect_to root_path
      end
    end

    def clear
      SmsOpener.clear!

      if json_request?
        head :no_content
      else
        redirect_to root_path
      end
    end

    private

    def json_request?
      request.format.json? || request.path.end_with?(".json") || request.headers["Accept"].to_s.include?("application/json")
    end

    def render_inbox_template
      template_file = File.expand_path("../../views/sms_opener/messages/index.html.erb", __dir__)
      ERB.new(File.read(template_file), trim_mode: "-").result(binding)
    end
  end
end
