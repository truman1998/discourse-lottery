# frozen_string_literal: true

module LotteryPlugin
  module Parser
    def self.parse(post, doc)
      # Rails.logger.info "LotteryPlugin Parser: Entered parse for post ID #{post.id}"
      return unless post.post_number == 1 # 示例：仅允许在第一个帖子中创建抽奖
      # Rails.logger.info "LotteryPlugin Parser: Post #{post.id} is first post."

      # 使用正确的命名空间 LotteryPlugin::Lottery
      if LotteryPlugin::Lottery.exists?(post_id: post.id)
        # Rails.logger.info "LotteryPlugin Parser: Lottery already exists for post ID #{post.id}. Skipping."
        return
      end

      # --- 实际解析逻辑的占位符 ---
      # 您需要定义如何在帖子中指定抽奖。
      # 当前版本使用一个简单的文本触发器。
      if doc.text.include?("[在此创建抽奖]") # 您的触发文本
        # Rails.logger.info "LotteryPlugin Parser: Found trigger text in post ID #{post.id}."
        begin
          created_lottery = LotteryPlugin::Lottery.create!(
            post_id: post.id,
            topic_id: post.topic_id,
            title: "帖子 #{post.id} 的示例抽奖",
            prize_name: "一份惊喜奖品!",
            points_cost: 5,
            max_entries: 50
          )
          Rails.logger.info "LotteryPlugin Parser: Successfully created lottery ##{created_lottery.id} for post ID #{post.id}"
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "LotteryPlugin Parser: ActiveRecord::RecordInvalid - Failed to create lottery for post ID #{post.id}. Errors: #{e.record.errors.full_messages.join(", ")}"
        rescue StandardError => e
          Rails.logger.error "LotteryPlugin Parser: StandardError - Unexpected error creating lottery for post ID #{post.id}. Error: #{e.class.name} - #{e.message}\nBacktrace: #{e.backtrace.take(5).join("\n")}"
        end
      # else
        # Rails.logger.info "LotteryPlugin Parser: Trigger text '[在此创建抽奖]' not found in post ID #{post.id}."
      end
      # --- 占位符结束 ---
    end
  end
end
