class CreateLotteryPluginEntries < ActiveRecord::Migration[6.1]
  def change
    create_table :lottery_plugin_entries do |t|
      t.integer :user_id, null: false    # 参与的用户ID
      t.integer :lottery_id, null: false # 用户参与的抽奖ID

      t.timestamps null: false # 添加 created_at 和 updated_at 时间戳
    end

    add_index :lottery_plugin_entries, [:user_id, :lottery_id], unique: true
    add_index :lottery_plugin_entries, :lottery_id
  end
end
