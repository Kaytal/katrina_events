require "rails_helper"

RSpec.describe Types::AdminType do
  let(:user) { create(:user) }

  describe "pages" do
    let(:query) { "{ admin { pages { slug published } } }" }

    it "includes drafts, which the public field hides" do
      create(:page, slug: "home")
      create(:page, :draft, slug: "about")

      result = execute_as(user, query)

      expect(dig_data(result, "admin", "pages")).to contain_exactly(
        { "slug" => "about", "published" => false },
        { "slug" => "home", "published" => true }
      )
    end

    it "returns a stable order, so the editor's list does not shuffle between saves" do
      %w[home contact about].each { |slug| create(:page, slug: slug) }

      result = execute_as(user, query)

      expect(dig_data(result, "admin", "pages").map { |page| page["slug"] })
        .to eq(%w[about contact home])
    end

    it "reports a page scheduled for the future as not yet published" do
      create(:page, :scheduled, slug: "soon")

      result = execute_as(user, query)

      expect(dig_data(result, "admin", "pages").first["published"]).to be(false)
    end
  end

  describe "page(slug:)" do
    let(:query) { 'query($slug: String!) { admin { page(slug: $slug) { slug title body } } }' }

    it "finds a draft, so she can work on copy before publishing it" do
      create(:page, :draft, slug: "about", body: "Half-written.")

      result = execute_as(user, query, variables: { "slug" => "about" })

      expect(dig_data(result, "admin", "page", "body")).to eq("Half-written.")
    end

    it "matches case-insensitively" do
      create(:page, slug: "about")

      result = execute_as(user, query, variables: { "slug" => " ABOUT " })

      expect(dig_data(result, "admin", "page", "slug")).to eq("about")
    end

    it "reports an unknown slug as NOT_FOUND" do
      result = execute_as(user, query, variables: { "slug" => "nope" })

      expect(error_codes(result)).to eq([ "NOT_FOUND" ])
    end
  end

  describe "the gate" do
    it "refuses the whole namespace without a token, so nothing beneath resolves" do
      create(:page, :draft, slug: "about", body: "Half-written.")

      result = execute_graphql("{ admin { pages { slug body } } }")

      expect(error_codes(result)).to eq([ "UNAUTHENTICATED" ])
      expect(result["data"]).to be_nil
      expect(result.to_json).not_to include("Half-written.")
    end
  end
end
