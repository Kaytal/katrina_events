# frozen_string_literal: true

module Mutations
  class UpdatePage < BaseMutation
    description "Edit one page's content. The slug is the identifier and cannot be changed — the three public routes are the site's structure, not content."

    argument :slug, String, required: true
    argument :title, String, required: false
    argument :body, String, required: false
    argument :meta_description, String, required: false
    argument :published, Boolean, required: false,
             description: "true publishes an unpublished page as of now; false makes it a draft. Leaves an already-set publish date alone, so re-saving a page does not shift it."

    field :page, Types::PageType, null: true
    field :errors, [ Types::FieldErrorType ], null: false

    def resolve(slug:, **attributes)
      require_admin!

      page = Page.find_by!(slug: slug.to_s.strip.downcase)

      published = attributes.delete(:published)
      page.assign_attributes(attributes)
      apply_publication(page, published) unless published.nil?

      if page.save
        { page: page, errors: [] }
      else
        # Validation failures come back in the payload, not as a top-level
        # error: the form needs to render them against their fields, and the
        # request itself did not fail.
        { page: nil, errors: field_errors(page) }
      end
    end

    private

    def apply_publication(page, published)
      if published
        # Only stamps a page that has no date. A page scheduled for next Tuesday
        # stays scheduled for next Tuesday.
        page.published_at ||= Time.current
      else
        page.published_at = nil
      end
    end
  end
end
