module LotteryPlugin
  class Lottery < ActiveRecord::Base
    self.table_name = "lottery_plugin_lotteries" # 明确设置表名

    # 关联关系
    has_many :entries, class_name: "LotteryPlugin::LotteryEntry", foreign_key: "lottery_id", dependent: :destroy # 抽奖有很多参与记录

    # 校验规则
    validates :post_id, presence: true, uniqueness: true # 每个帖子只能有一个抽奖
    validates :topic_id, presence: true # 必须关联到主题ID
    validates :title, presence: true, length: { maximum: 255 } # 抽奖标题不能为空，最大长度255
    validates :prize_name, presence: true, length: { maximum: 255 } # 奖品名称不能为空，最大长度255
    validates :points_cost, numericality: { greater_than_or_equal_to: 0, only_integer: true } # 消耗积分必须大于等于0的整数
    validates :max_entries, numericality: { greater_than: 0, only_integer: true, allow_nil: true } # 最大参与人数如果设置，必须是正整数
  end
end
