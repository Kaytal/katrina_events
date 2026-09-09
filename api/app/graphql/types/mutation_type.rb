# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :login, mutation: Mutations::Login
    field :logout, mutation: Mutations::Logout

    field :update_page, mutation: Mutations::UpdatePage

    field :create_event, mutation: Mutations::CreateEvent
    field :update_event, mutation: Mutations::UpdateEvent
    field :delete_event, mutation: Mutations::DeleteEvent

    field :create_event_exception, mutation: Mutations::CreateEventException
    field :delete_event_exception, mutation: Mutations::DeleteEventException

    field :create_availability_pattern, mutation: Mutations::CreateAvailabilityPattern
    field :update_availability_pattern, mutation: Mutations::UpdateAvailabilityPattern
    field :delete_availability_pattern, mutation: Mutations::DeleteAvailabilityPattern

    field :update_time_block, mutation: Mutations::UpdateTimeBlock
    field :materialize_time_blocks, mutation: Mutations::MaterializeTimeBlocks

    field :create_venue, mutation: Mutations::CreateVenue
    field :update_venue, mutation: Mutations::UpdateVenue
  end
end
