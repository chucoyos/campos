class YardAreasController < ApplicationController
  def update
    area = YardArea.find(params[:id])
    authorize area

    if area.update(params.expect(yard_area: %i[capacity enabled]))
      redirect_to yard_path, notice: t("flash.yard.area_updated", name: area.name)
    else
      redirect_to yard_path, alert: area.errors.full_messages.to_sentence
    end
  end
end
