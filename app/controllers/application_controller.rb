class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Method

  PER_PAGE_OPTIONS = [ 10, 25, 50, 100 ].freeze

  before_action :authenticate_user!
  helper_method :per_page_options, :per_page, :filter_fields, :active_filters

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

  private

  def per_page_options = PER_PAGE_OPTIONS

  def per_page
    PER_PAGE_OPTIONS.find { |option| option == params[:per_page].to_i } || PER_PAGE_OPTIONS.first
  end

  # Cada campo: name, type (:text | :select), label, options ([[etiqueta, valor]]) y apply (->(scope, valor)).
  def filter_fields = []

  def filter_value(field)
    value = params[field[:name]].to_s.strip
    return if value.blank?
    return if field[:type] == :select && field[:options].none? { |_label, option| option.to_s == value }

    value
  end

  def active_filters
    filter_fields.filter_map do |field|
      value = filter_value(field)
      next unless value

      display = field[:type] == :select ? field[:options].find { |_label, option| option.to_s == value }.first : value
      { name: field[:name], label: field[:label], value: display }
    end
  end

  def apply_filters(scope)
    filter_fields.reduce(scope) do |current, field|
      value = filter_value(field)
      value ? field[:apply].call(current, value) : current
    end
  end

  def like(value) = "%#{ActiveRecord::Base.sanitize_sql_like(value)}%"

  def paginate(scope)
    pagy(scope, limit: per_page, raise_range_error: true)
  end
end
