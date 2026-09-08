# A denylist, not an allowlist: tokens are valid until logout puts their jti
# here, which is what makes logout genuinely invalidate a token rather than
# just dropping it on the client.
class CreateJwtDenylist < ActiveRecord::Migration[8.1]
  def change
    create_table :jwt_denylist do |t|
      t.string :jti, null: false
      t.datetime :exp, null: false
    end

    # Looked up on every authenticated request, so it needs the index.
    add_index :jwt_denylist, :jti, unique: true
    # The sweep job (Phase 8) deletes rows past expiry.
    add_index :jwt_denylist, :exp
  end
end
