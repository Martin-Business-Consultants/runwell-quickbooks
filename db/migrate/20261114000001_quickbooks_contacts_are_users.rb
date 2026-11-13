# Runwell 5.1 made a client's contacts users (`users.legacy_contact_id` keeps each old contact
# id). A recurring invoice's and a billing plan's contact_id still naming the old `contacts`
# table is moved onto the same person's user id, and its foreign key onto `users`.
class QuickbooksContactsAreUsers < ActiveRecord::Migration[8.1]
  TABLES = %i[quickbooks_recurring_links quickbooks_billing_plans]

  def up
    TABLES.each do |table|
      next unless table_exists?(table) && foreign_keys(table).any? { it.to_table == "contacts" }

      execute "UPDATE #{table} SET contact_id = (SELECT id FROM users WHERE users.legacy_contact_id = #{table}.contact_id) WHERE contact_id IS NOT NULL"
      remove_foreign_key table, column: :contact_id
      add_foreign_key table, :users, column: :contact_id
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
