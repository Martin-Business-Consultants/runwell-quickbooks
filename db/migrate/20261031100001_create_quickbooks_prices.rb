# Runwell 3.0 took agreements (and their prices) out of the core: what QuickBooks bills an
# engagement is now set here, on its Billing tab. Each engagement's price starts as what its
# approved agreements came to, read from the core's old tables while they're still there.
class CreateQuickbooksPrices < ActiveRecord::Migration[8.1]
  def up
    # Runwell 5.0.3 renamed engagements to works; 20261114000000 renames the column after.
    works = table_exists?(:works) ? "works" : "engagements"
    create_table :quickbooks_prices do |t|
      t.references :engagement, null: false, foreign_key: { to_table: works }, index: { unique: true }
      t.integer :amount_cents, null: false, default: 0
      t.string :cadence
      t.references :set_by, foreign_key: { to_table: :users }
      t.timestamps
    end

    return unless table_exists?(:agreement_versions) && table_exists?(:approvals)

    approved = select_rows(<<~SQL)
      SELECT agreement_versions.engagement_id, #{works}.shape, agreement_versions.kind, agreement_versions.amount_cents,
             agreement_versions.price_delta_cents, agreement_versions.cadence
      FROM agreement_versions
      JOIN approvals ON approvals.agreement_version_id = agreement_versions.id AND approvals.decision = 'approved'
      JOIN #{works} ON #{works}.id = agreement_versions.engagement_id
      ORDER BY agreement_versions.engagement_id, agreement_versions.number
    SQL
    approved.group_by(&:first).each do |engagement_id, versions|
      recurring = versions.first[1] == "recurring"
      amount = recurring ? versions.last[3].to_i : versions.sum { |_, _, kind, cents, delta| kind == "initial" ? cents.to_i : delta.to_i }
      next unless amount.positive?

      cadence = recurring ? (versions.last[5].presence || "monthly") : nil
      execute "INSERT INTO quickbooks_prices (engagement_id, amount_cents, cadence, created_at, updated_at) " \
              "VALUES (#{engagement_id.to_i}, #{amount}, #{cadence ? quote(cadence) : "NULL"}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
    end
  end

  def down
    drop_table :quickbooks_prices
  end
end
