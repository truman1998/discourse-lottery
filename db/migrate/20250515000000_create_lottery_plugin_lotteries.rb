class CreateLotteryPluginLotteries < ActiveRecord::Migration[6.1]
  def change
    create_table :lottery_plugin_lotteries do |t|
      t.integer :topic_id, null: false      # 用于关联到主题
      t.integer :post_id, null: false       # 用于关联到特定的帖子
      t.string  :title, null: false         # 抽奖的标题 (例如, "特等奖抽奖")
      t.string  :prize_name, null: false    # 奖品的名称 (例如, "一辆新车!")
      t.integer :points_cost, default: 0, null: false # 参与所需的积分成本
      t.integer :max_entries                # 可选: 允许的最大参与人数

      t.timestamps null: false # 添加 created_at 和 updated_at 时间戳
    end

    add_index :lottery_plugin_lotteries, :post_id, unique: true
    add_index :lottery_plugin_lotteries, :topic_id
  end
end
