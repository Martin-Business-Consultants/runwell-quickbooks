# Runwell 5.0.3 renamed engagements to work (`works`, `work_id`). The plugin's own tables follow:
# each engagement_id becomes work_id, renamed in place (SQLite keeps its rows and the foreign key
# with it), and a foreign key still naming the old `engagements` table (one made on a core that
# had already renamed it) points at `works`.
class QuickbooksEngagementsAreWork < ActiveRecord::Migration[8.1]
  TABLES = %i[quickbooks_recurring_links quickbooks_invoices quickbooks_billing_plans quickbooks_prices]

  def up
    TABLES.each do |table|
      next unless table_exists?(table) && column_exists?(table, :engagement_id)

      execute "ALTER TABLE #{table} RENAME COLUMN engagement_id TO work_id"
      if foreign_keys(table).any? { it.to_table == "engagements" }
        remove_foreign_key table, column: :work_id
        add_foreign_key table, :works, column: :work_id
      end
      old_index = "index_#{table}_on_engagement_id"
      rename_index table, old_index, "index_#{table}_on_work_id" if index_name_exists?(table, old_index)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
