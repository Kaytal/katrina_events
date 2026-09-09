# Regeneration closes a block whose occurrence was cancelled. It must not, on
# the next run, reopen a block *she* closed by hand — and without a marker the
# two are indistinguishable, so restoring a cancelled session would leave its
# block shut and un-requestable for reasons nobody could see.
class AddAutoClosedToTimeBlocks < ActiveRecord::Migration[8.1]
  def change
    add_column :time_blocks, :auto_closed, :boolean, null: false, default: false
  end
end
