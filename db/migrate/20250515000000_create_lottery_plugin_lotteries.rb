class CreateLotteryPluginLotteries < ActiveRecord::Migration[6.1]
  def change
    create_table :lottery_plugin_lotteries do |t|
      t.integer :topic_id, null: false      # 用于关联到主题
      t.integer :post_id, null: false       # 用于关联到特定的帖子
      t.string  :title, null: false         # 抽奖的标题 (例如, "特等奖抽奖")
      t.string  :prize_name, null: false    # 奖品的名称 (例如, "一辆新车!")
      t.integer :points_cost, default: 0, null: false # 参与所需的积分成本
      t.integer :max_entries                # 可选: 允许的最大参与人数
      # t.datetime :ends_at                 # 可选: 抽奖结束时间
      # t.integer :winner_user_id           # 可选: 用于存储中奖用户ID

      t.timestamps null: false # 添加 created_at 和 updated_at 时间戳
    end

    # 为 post_id 添加索引以便快速查找，并如果模型校验需要则强制唯一性
    add_index :lottery_plugin_lotteries, :post_id, unique: true
    # 为 topic_id 添加索引
    add_index :lottery_plugin_lotteries, :topic_id
  end
end
