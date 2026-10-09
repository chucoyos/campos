# Pantallas de error servidas por config.exceptions_app. Hereda de Base a propósito:
# no depende de Devise, Pundit ni de la base de datos, que pueden ser la causa del error.
class ErrorsController < ActionController::Base
  CODES = %w[400 404 422 500].freeze

  layout "errors"

  def show
    @code = CODES.include?(params[:code]) ? params[:code] : "500"
    @status = @code.to_i

    respond_to do |format|
      format.html { render status: @status }
      format.any { head @status }
    end
  end
end
