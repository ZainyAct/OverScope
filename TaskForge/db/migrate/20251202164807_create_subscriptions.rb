class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.string :stripe_customer_id
      t.string :stripe_subscription_id
      t.string :status, default: 'incomplete'
      t.timestamp :current_period_end

      t.timestamps
    end

  end
end

