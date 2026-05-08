# frozen_string_literal: true

RSpec.describe TsykvasRailsTemplate do
  it "has a version number" do
    expect(TsykvasRailsTemplate::VERSION).not_to be_nil
  end

  it "exposes the deterministic Probe API" do
    expect(TsykvasRailsTemplate::Probe).to respond_to(:run)
  end
end
