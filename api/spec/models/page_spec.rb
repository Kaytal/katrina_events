require "rails_helper"

RSpec.describe Page do
  it "requires a slug and a title" do
    page = described_class.new

    expect(page).not_to be_valid
    expect(page.errors[:slug]).to be_present
    expect(page.errors[:title]).to be_present
  end

  it "rejects a duplicate slug regardless of case" do
    create(:page, slug: "about")

    duplicate = build(:page, slug: "ABOUT")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:slug]).to be_present
  end

  it "downcases and strips the slug on assignment" do
    page = described_class.new(slug: "  About  ")

    expect(page.slug).to eq("about")
  end

  it "rejects slugs that are not lowercase, dash-separated" do
    expect(build(:page, slug: "about us")).not_to be_valid
    expect(build(:page, slug: "about_us")).not_to be_valid
    expect(build(:page, slug: "about-us")).to be_valid
  end

  describe "publication" do
    it "treats a null published_at as a draft" do
      expect(create(:page, :draft)).not_to be_published
    end

    it "treats a future published_at as not yet published" do
      expect(create(:page, :scheduled)).not_to be_published
    end

    it "excludes drafts and scheduled pages from the published scope" do
      live = create(:page)
      create(:page, :draft)
      create(:page, :scheduled)

      expect(described_class.published).to contain_exactly(live)
    end
  end
end
