# Runwell 5.1 made a client's contacts users (`users.legacy_contact_id` keeps each old contact
# id). A recurring invoice's and a billing plan's contact_id still naming the old `contacts`
# table is moved onto the same person's user id, and its foreign key onto `users`. The key moves
# first and the ids after, with foreign keys checked only at commit, so neither step trips over
# the other (a user id isn't a contact id, nor the reverse); a contact with no user is cleared.
class QuickbooksContactsAreUsers < ActiveRecord::Migration[8.1]
  TABLES = %i[quickbooks_recurring_links quickbooks_billing_plans]

  def up
    TABLES.each do |table|
      next unless table_exists?(table) && foreign_keys(table).any? { it.to_table == "contacts" }

      disable_referential_integrity do
        remove_foreign_key table, column: :contact_id
        add_foreign_key table, :users, column: :contact_id
        execute "UPDATE #{table} SET contact_id = (SELECT id FROM users WHERE users.legacy_contact_id = #{table}.contact_id) WHERE contact_id IS NOT NULL"
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
