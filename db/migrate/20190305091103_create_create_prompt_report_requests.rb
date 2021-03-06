class CreateCreatePromptReportRequests < ActiveRecord::Migration[5.1]
  def change
    create_table :create_prompt_report_requests do |t|
      t.integer  :user_id,     null: false
      t.datetime :finished_at, null: true, default: nil

      t.timestamps null: false

      t.index :user_id
      t.index :created_at
    end
  end
end
