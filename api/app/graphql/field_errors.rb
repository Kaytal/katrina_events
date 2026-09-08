# Turns Active Record validation errors into the payload shape the admin forms
# render directly. Field names are camelCased to match the input the form sent,
# so a form can look up messages by the same key it submitted.
module FieldErrors
  private

  def field_errors(record)
    record.errors.group_by(&:attribute).map do |attribute, errors|
      {
        field: attribute.to_s.camelize(:lower),
        messages: errors.map(&:message)
      }
    end
  end
end
