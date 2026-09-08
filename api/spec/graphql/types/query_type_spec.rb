require "rails_helper"

RSpec.describe Types::QueryType do
  describe "page(slug:)" do
    let(:query) do
      <<~GRAPHQL
        query Page($slug: String!) {
          page(slug: $slug) {
            slug
            title
            body
            metaDescription
            publishedAt
            updatedAt
          }
        }
      GRAPHQL
    end

    it "returns a published page, with the body as Markdown source" do
      create(:page, slug: "about", title: "About Katrina", body: "## Hi\n\nCopy.",
                    meta_description: "About me.")

      result = execute_graphql(query, variables: { "slug" => "about" })

      expect(result["errors"]).to be_nil
      expect(dig_data(result, "page")).to include(
        "slug" => "about",
        "title" => "About Katrina",
        "body" => "## Hi\n\nCopy.",
        "metaDescription" => "About me."
      )
    end

    it "matches a slug case-insensitively and ignores surrounding whitespace" do
      create(:page, slug: "about")

      expect(dig_data(execute_graphql(query, variables: { "slug" => " ABOUT " }), "page", "slug"))
        .to eq("about")
    end

    it "reports an unknown slug as NOT_FOUND rather than a bare null" do
      result = execute_graphql(query, variables: { "slug" => "nope" })

      expect(dig_data(result, "page")).to be_nil
      expect(error_codes(result)).to eq([ "NOT_FOUND" ])
    end

    it "hides a draft page and does not leak its body" do
      create(:page, :draft, slug: "secret", body: "Not ready.")

      result = execute_graphql(query, variables: { "slug" => "secret" })

      expect(error_codes(result)).to eq([ "NOT_FOUND" ])
      expect(result.to_json).not_to include("Not ready.")
    end

    it "hides a page scheduled for the future" do
      create(:page, :scheduled, slug: "soon")

      result = execute_graphql(query, variables: { "slug" => "soon" })

      expect(error_codes(result)).to eq([ "NOT_FOUND" ])
    end
  end

  describe "health" do
    it "reports the service, environment, and configured time zone" do
      result = execute_graphql("{ health { status service environment timeZone database } }")

      expect(dig_data(result, "health")).to include(
        "status" => "ok",
        "service" => "katrina-events-api",
        "environment" => "test",
        "timeZone" => "America/Denver",
        "database" => "connected"
      )
    end

    it "reports degraded rather than raising when the database probe fails" do
      allow(ActiveRecord::Base.connection)
        .to receive(:execute).with("SELECT 1")
        .and_raise(ActiveRecord::ConnectionNotEstablished)

      result = execute_graphql("{ health { status database } }")

      expect(result["errors"]).to be_nil
      expect(dig_data(result, "health")).to include(
        "status" => "degraded",
        "database" => "unavailable"
      )
    end
  end
end
