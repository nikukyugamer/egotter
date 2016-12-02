class CreateUserEngagementStats < ActiveRecord::Migration
  def change
    create_table :user_engagement_stats do |t|
      t.datetime :date,  null: false
      t.integer  :total, null: false, default: 0

      (1..30).each { |n| t.integer "#{n}_days", null: false, default: 0 }
      (1..30).each { |n| t.integer "before_#{n}_days", null: false, default: 0 }

      t.timestamps null: false
    end

    add_index :user_engagement_stats, :date, unique: true
  end
end