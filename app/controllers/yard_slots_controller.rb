class YardSlotsController < ApplicationController
  def toggle
    slot = YardSlot.find(params[:id])
    authorize slot
    slot.update!(enabled: !slot.enabled)
    redirect_back_or_to yard_path, notice: t("flash.yard.slot_#{slot.enabled ? 'enabled' : 'disabled'}", code: slot.code)
  end
end
