class RehandlingRequestService
  Error = MovementPlanService::Error

  def self.start_exit(pass:, user:)
    MovementPlanService.start_exit(pass:, user:)
  end

  def self.advance(request)
    MovementPlanService.advance(request.movement_plan) if request.movement_plan
  end

  def self.advance_pending
    MovementPlanService.advance_pending
  end

  def self.create_independent(container:, user:, destination_id:)
    MovementPlanService.create_independent(container:, user:, destination_id:)
  end

  def self.cancel(request:, user:)
    MovementPlanService.cancel(plan: request.movement_plan, user:)
  end
end
