require "rails_helper"

RSpec.describe Venue do
  it "requires a name" do
    expect(described_class.new).not_to be_valid
  end

  it "rejects a duplicate name regardless of case" do
    create(:venue, name: "Uplift")

    expect(build(:venue, name: "uplift")).not_to be_valid
  end

  describe "url" do
    it "accepts a full http or https URL" do
      expect(build(:venue, url: "https://example.invalid/festival")).to be_valid
      expect(build(:venue, url: "http://example.invalid")).to be_valid
    end

    it "allows no URL at all" do
      expect(build(:venue, url: nil)).to be_valid
      expect(build(:venue, url: "")).to be_valid
    end

    it "rejects a scheme-less value" do
      expect(build(:venue, url: "example.invalid")).not_to be_valid
    end

    # A leading anchor alone would pass this: the URL is fine and the tail rides
    # along to wherever it is rendered.
    it "rejects trailing content after a valid-looking prefix" do
      expect(build(:venue, url: "https://ok.example\njavascript:alert(1)")).not_to be_valid
      expect(build(:venue, url: "https://ok.example some other text")).not_to be_valid
    end
  end
end
