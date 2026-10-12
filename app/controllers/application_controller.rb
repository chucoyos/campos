class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Method

  before_action :authenticate_user!

  rescue_from Pundit::NotAuthorizedError do
    redirect_back_or_to root_path, alert: t("flash.application.not_authorized")
  end

  # Una página fuera de rango lleva a la última página disponible.
  rescue_from Pagy::RangeError do |error|
    redirect_to url_for(request.query_parameters.merge(page: error.pagy.last, only_path: true))
  end

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
