module LotteryPlugin
  class EntriesController < ::ApplicationController
    requires_plugin LotteryPlugin::PLUGIN_NAME # 使用常量指定插件名称
    before_action :ensure_logged_in # 用户必须登录才能参与

    def create
      # 通过参数中的 ID 查找抽奖
      lottery = LotteryPlugin::Lottery.find_by(id: params[:lottery_id])
      unless lottery
        return render_json_error(I18n.t("lottery.errors.not_found"), status: 404) # 未找到抽奖
      end

      # 检查抽奖是否已满 (如果设置了 max_entries)
      if lottery.max_entries && lottery.entries.count >= lottery.max_entries
        return render_json_error(I18n.t("lottery.errors.reached_max_entries"), status: 403) # 达到最大参与人数
      end

      # 积分检查 (如果 points_cost > 0)
      # 这里假设您有一个与 User 模型集成的积分系统。
      # `can_spend_points?` 和 `spend_points!` 方法是示例性的。
      # 您需要根据实际的积分系统逻辑进行调整。
      # 例如，如果使用 discourse-gamification:
      # GamificationScore.calculate_scores # 确保分数是最新的
      # current_user_score = UserGamificationScore.find_by(user_id: current_user.id)&.score || 0
      # if lottery.points_cost > 0 && current_user_score < lottery.points_cost
      #   return render_json_error(I18n.t("lottery.errors.insufficient_points", cost: lottery.points_cost), status: 402)
      # end
      #
      # 原始代码使用了 `current_user.can_award_self?(-lottery.points_cost)`
      # 和 `current_user.award_points`。这可能特定于某个积分插件。
      # 我暂时保留原始逻辑，假设它来自一个已知的积分系统。
      if lottery.points_cost > 0
        # 如果是 UserPoints 系统，则直接使用。
        # 如果您有 UserPoint 模型，这是一种常见模式。
        # 让我们假设 `current_user.points_balance` 和一个扣除积分的服务。
        # 为简单起见，我将坚持使用提供的 `can_award_self?` 和 `award_points`。
        # 确保这些方法存在于您的 User 模型或其扩展中。
        unless current_user.respond_to?(:can_award_self?) && current_user.can_award_self?(-lottery.points_cost)
           return render_json_error(
             I18n.t("lottery.errors.insufficient_points", cost: lottery.points_cost), # 积分不足
             status: 402 # Payment Required (需要付款)
           )
        end
      end

      entry = LotteryPlugin::LotteryEntry.new(lottery: lottery, user: current_user) # 创建新的参与记录对象

      ActiveRecord::Base.transaction do # 使用数据库事务确保原子性
        # 如果适用，则扣除积分
        if lottery.points_cost > 0
          if current_user.respond_to?(:award_points)
            # 积分扣除原因
            reason_for_deduction = I18n.t("lottery.points_deduction_reason", title: ActionController::Base.helpers.sanitize(lottery.title))

            current_user.award_points(
              -lottery.points_cost, # 负值表示扣除
              awarded_by: Discourse.system_user, # 或其他适当的用户
              reason: reason_for_deduction
              # topic_id: lottery.topic_id, # 可选: 关联到主题
              # post_id: lottery.post_id    # 可选: 关联到帖子
            )
            # 如果 `award_points` 没有保存用户积分，则确保保存。
            current_user.save! # 或处理潜在的保存错误
          else
            # 如果 award_points 方法缺失，则回退或报错
            Rails.logger.error "LotteryPlugin: User 模型没有响应 award_points 方法。无法扣除积分。"
            raise ActiveRecord::Rollback, I18n.t("lottery.errors.points_system_error") # 积分系统错误
          end
        end

        # 创建参与记录
        unless entry.save
          # 如果保存失败，事务将回滚。
          # 错误将被下面的 rescue 块捕获。
          # 如果使用 save!，则无需在此处显式引发 ActiveRecord::Rollback。
          # entry.save! 会直接引发异常。
          # 使用 save 然后检查错误：
          return render_json_error(entry.errors.full_messages.join(", "), status: 422)
        end
      end

      # 成功创建参与记录
      remaining_entries = if lottery.max_entries
                            lottery.max_entries - lottery.entries.reload.count # reload 以获取最新计数
                          else
                            nil # 表示不限制参与人数
                          end

      render json: {
        success: true,
        message: I18n.t("lottery.success_joined"), # 成功参与
        remaining_entries: remaining_entries,
        total_entries: lottery.entries.count # 参与后的当前总人数
      }, status: :created

    rescue ActiveRecord::RecordInvalid => e
      # 捕获来自 entry.save! 或其他模型 save! 调用的校验错误
      render_json_error(e.record.errors.full_messages.join(", "), status: 422)
    rescue ActiveRecord::Rollback => e
      # 处理显式回滚或导致事务失败的错误
      # 回滚的消息可能是通用的，如果可能，请使用特定的消息
      render_json_error(e.message || I18n.t("lottery.errors.transaction_failed"), status: 422) # 事务失败
    rescue StandardError => e
      # 捕获任何其他意外错误
      Rails.logger.error "LotteryPlugin 错误: #{e.message}\n#{e.backtrace.join("\n")}"
      render_json_error(I18n.t("lottery.errors.generic_error"), status: 500) # 通用错误
    end
  end
end
