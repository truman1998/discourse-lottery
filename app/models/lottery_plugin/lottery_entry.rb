module LotteryPlugin
  class LotteryEntry < ActiveRecord::Base
    self.table_name = "lottery_plugin_entries" # 明确设置表名

    # 关联关系
    belongs_to :lottery, class_name: "LotteryPlugin::Lottery" # 参与记录属于某个抽奖
    belongs_to :user # 参与记录属于某个用户

    # 校验规则
    validates :user_id, presence: true # 用户ID不能为空
    validates :lottery_id, presence: true # 抽奖ID不能为空

    # 确保一个用户只能参与一个特定的抽奖一次
    validates :user_id, uniqueness: {
      scope: :lottery_id, # 作用域限定在同一个 lottery_id 内
      message: ->(object, data) { I18n.t("lottery.errors.already_participated") } # 使用 I18n 获取错误消息
    }

    # 校验关联对象是否存在
    validates :lottery, presence: true # 必须关联到抽奖
    validates :user, presence: true   # 必须关联到用户
  end
end
