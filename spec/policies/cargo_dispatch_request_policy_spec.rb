require "rails_helper"

RSpec.describe CargoDispatchRequestPolicy do
  describe "#remove_instruction?" do
    let(:client) { create(:client) }
    let(:owner) { create(:user, :cliente, client: client) }
    let(:request_record) { CargoDispatchRequest.create!(client: client, requested_by: owner, destination: "Destino") }

    it "allows the owner and administrator while pending or in progress" do
      admin = create(:user, :admin)
      [ "pending", "in_progress" ].each do |status|
        request_record.status = status
        expect(described_class.new(owner, request_record).remove_instruction?).to be(true)
        expect(described_class.new(admin, request_record).remove_instruction?).to be(true)
      end
    end

    it "rejects other customers and closed requests" do
      other = create(:user, :cliente, client: create(:client))
      expect(described_class.new(other, request_record).remove_instruction?).to be(false)
      request_record.status = "completed"
      expect(described_class.new(owner, request_record).remove_instruction?).to be(false)
      expect(described_class.new(create(:user, :admin), request_record).remove_instruction?).to be(false)
    end
  end
end
