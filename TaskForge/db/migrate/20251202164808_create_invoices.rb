class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :invoices, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.string :stripe_invoice_id
      t.integer :amount_cents
      t.string :currency, default: 'usd'
      t.string :status
      t.date :billing_date

      t.timestamps
    end

    add_index :invoices, [:organization_id, :billing_date]
  end
end

