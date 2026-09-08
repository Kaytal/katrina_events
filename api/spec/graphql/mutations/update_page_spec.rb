require "rails_helper"

RSpec.describe Mutations::UpdatePage do
  let(:user) { create(:user) }
  let!(:page) { create(:page, slug: "about", title: "About", body: "Old copy.") }

  let(:query) do
    <<~GRAPHQL
      mutation Update(
        $slug: String!, $title: String, $body: String,
        $metaDescription: String, $published: Boolean
      ) {
        updatePage(input: {
          slug: $slug, title: $title, body: $body,
          metaDescription: $metaDescription, published: $published
        }) {
          page { slug title body metaDescription published publishedAt }
          errors { field messages }
        }
      }
    GRAPHQL
  end

  def update(variables, as: user)
    execute_as(as, query, variables: variables)
  end

  it "refuses an unauthenticated request and changes nothing" do
    result = execute_graphql(query, variables: { "slug" => "about", "title" => "Hacked" })

    expect(error_codes(result)).to eq([ "UNAUTHENTICATED" ])
    expect(page.reload.title).to eq("About")
  end

  it "saves the title and body" do
    result = update({ "slug" => "about", "title" => "About Katrina", "body" => "## New copy" })

    expect(dig_data(result, "updatePage", "errors")).to be_empty
    expect(page.reload).to have_attributes(title: "About Katrina", body: "## New copy")
  end

  it "leaves fields that were not sent alone" do
    update({ "slug" => "about", "title" => "Only the title" })

    expect(page.reload.body).to eq("Old copy.")
  end

  it "cannot change the slug, which is the site's structure rather than content" do
    expect(described_class.arguments.keys).not_to include("newSlug")

    update({ "slug" => "about", "title" => "Renamed?" })

    expect(page.reload.slug).to eq("about")
  end

  describe "validation failures" do
    it "returns field errors in the payload rather than as a request error" do
      result = update({ "slug" => "about", "title" => "" })

      expect(result["errors"]).to be_nil
      expect(dig_data(result, "updatePage", "page")).to be_nil
      expect(dig_data(result, "updatePage", "errors")).to eq(
        [ { "field" => "title", "messages" => [ "can't be blank" ] } ]
      )
    end

    it "names the field in camelCase, matching the input the form sent" do
      result = update({ "slug" => "about", "metaDescription" => "x" * 400 })

      expect(dig_data(result, "updatePage", "errors").first["field"]).to eq("metaDescription")
    end

    it "writes nothing at all when validation fails" do
      update({ "slug" => "about", "title" => "", "body" => "This should not persist." })

      expect(page.reload).to have_attributes(title: "About", body: "Old copy.")
    end
  end

  describe "publication" do
    it "publishes a draft as of now" do
      draft = create(:page, :draft, slug: "home")

      freeze_time do
        update({ "slug" => "home", "published" => true })
        expect(draft.reload.published_at).to eq(Time.current)
      end
    end

    it "makes a published page a draft again" do
      update({ "slug" => "about", "published" => false })

      expect(page.reload.published_at).to be_nil
      expect(Page.published).not_to include(page)
    end

    # Otherwise every ordinary save would quietly bring a scheduled page forward.
    it "leaves an existing publish date alone when re-publishing" do
      scheduled = create(:page, :scheduled, slug: "soon")
      original = scheduled.published_at

      update({ "slug" => "soon", "published" => true, "title" => "Edited while scheduled" })

      expect(scheduled.reload.published_at).to be_within(1.second).of(original)
    end

    it "does not touch publication when `published` is omitted" do
      original = page.published_at

      update({ "slug" => "about", "title" => "Just a copy edit" })

      expect(page.reload.published_at).to be_within(1.second).of(original)
    end
  end

  it "reports an unknown slug as NOT_FOUND" do
    result = update({ "slug" => "nope", "title" => "x" })

    expect(error_codes(result)).to eq([ "NOT_FOUND" ])
  end
end
