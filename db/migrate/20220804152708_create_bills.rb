class CreateBills < ActiveRecord::Migration[7.0]
  def change
    create_table :bills do |t|
      t.references :user, foreign_key: true
      t.string :month
      t.integer :amount
      t.string :description

      t.timestamps
    end
  end
end
