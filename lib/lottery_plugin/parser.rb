# frozen_string_literal: true

module LotteryPlugin
  module Parser
    # 解析帖子内容以创建抽奖。
    #
    # 参数:
    # - post: 正在处理的 Post 对象。
    # - doc: 一个 Nokogiri::HTML::DocumentFragment，表示已渲染的帖子内容。
    def self.parse(post, doc)
      # Rails.logger.info "LotteryPlugin Parser: Entered parse for post ID #{post.id}"
      # 示例：仅允许在第一个帖子中创建抽奖
      return unless post.post_number == 1
      # Rails.logger.info "LotteryPlugin Parser: Post #{post.id} is first post."

      # 检查此帖子是否已存在抽奖
      if LotteryPlugin::Lottery.exists?(post_id: post.id)
        # Rails.logger.info "LotteryPlugin Parser: Lottery already exists for post ID #{post.id}. Skipping."
        return
      end

      # --- 实际解析逻辑的占位符 ---
      # 您需要定义如何在帖子中指定抽奖。
      # 例如，查找自定义 BBCode `[lottery title="奖品" cost="10"]` 或特定的 HTML 结构。
      # 当前版本使用一个简单的文本触发器。

      # 示例：查找文本 "[在此创建抽奖]" 来触发抽奖创建
      if doc.text.include?("[在此创建抽奖]")
        # Rails.logger.info "LotteryPlugin Parser: Found trigger text in post ID #{post.id}."
        begin
          # 使用正确的命名空间 LotteryPlugin::Lottery
          created_lottery = LotteryPlugin::Lottery.create!(
            post_id: post.id,
            topic_id: post.topic_id,
            title: "帖子 #{post.id} 的示例抽奖", # "示例抽奖"
            prize_name: "一份惊喜奖品!", # "惊喜奖品"
            points_cost: 5,
            max_entries: 50
          )
          Rails.logger.info "LotteryPlugin Parser: Successfully created lottery ##{created_lottery.id} for post ID #{post.id}"
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "LotteryPlugin Parser: Failed to create lottery for post ID #{post.id}. Errors: #{e.record.errors.full_messages.join(", ")}"
        rescue StandardError => e # 捕获更广泛的错误
          Rails.logger.error "LotteryPlugin Parser: Unexpected error creating lottery for post ID #{post.id}. Error: #{e.class.name} - #{e.message}\nBacktrace: #{e.backtrace.take(5).join("\n")}"
        end
      # else
        # Rails.logger.info "LotteryPlugin Parser: Trigger text not found in post ID #{post.id}."
      end
      # --- 占位符结束 ---

      # 如果您希望修改 `doc` (已渲染的 HTML) 以插入抽奖框的占位符，可以在这里进行。
      # 例如，如果通过 BBCode 创建了抽奖，您可能想将 BBCode 替换为
      # <div class="lottery-box" data-lottery-id="..."></div>
      # 然后 JavaScript 初始化器会找到并填充它。
      # 当前 `lottery.js.es6` 会查找具有 `lottery_data` 的帖子，并尝试修饰
      # 一个已存在的 `.lottery-box` 或在帖子末尾创建一个。
      # 因此，如果 `parser.rb` 创建了一个 Lottery 记录，
      # 并且帖子的 cooked HTML 中还没有 `.lottery-box`，JS 也会尝试处理。
    end
  end
end
