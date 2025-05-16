module LotteryPlugin
  class EntriesController < ::ApplicationController
    requires_plugin LotteryPlugin::PLUGIN_NAME # 使用常量指定插件名称
    before_action :ensure_logged_in # 用户必须登录才能参与

    def create
      lottery = LotteryPlugin::Lottery.find_by(id: params[:lottery_id])
      unless lottery
        return render_json_error(I18n.t("lottery.errors.not_found"), status: 404) # 未找到抽奖
      end

      if lottery.max_entries && lottery.entries.count >= lottery.max_entries
        return render_json_error(I18n.t("lottery.errors.reached_max_entries"), status: 403) # 达到最大参与人数
      end

      if lottery.points_cost > 0
        # 确保 User 模型响应 can_award_self? 和 award_points 方法
        # 这是 Discourse Gamification 插件或其他类似积分系统可能提供的方法
        unless current_user.respond_to?(:can_award_self?) && current_user.can_award_self?(-lottery.points_cost)
           return render_json_error(
             I18n.t("lottery.errors.insufficient_points", cost: lottery.points_cost), # 积分不足
             status: 402 # Payment Required
           )
        end
      end

      entry = LotteryPlugin::LotteryEntry.new(lottery: lottery, user: current_user) # 创建新的参与记录对象

      ActiveRecord::Base.transaction do # 使用数据库事务确保原子性
        if lottery.points_cost > 0
          if current_user.respond_to?(:award_points)
            reason_for_deduction = I18n.t("lottery.points_deduction_reason", title: ActionController::Base.helpers.sanitize(lottery.title))
            current_user.award_points(
              -lottery.points_cost,
              awarded_by: Discourse.system_user,
              reason: reason_for_deduction
            )
            current_user.save! # 确保用户积分更改被保存
          else
            Rails.logger.error "LotteryPlugin: User 模型没有响应 award_points 方法。无法扣除积分。"
            raise ActiveRecord::Rollback, I18n.t("lottery.errors.points_system_error") # 积分系统错误
          end
        end

        unless entry.save
          # 如果保存失败，事务将回滚。错误将由下面的 rescue 块捕获。
          # 使用 save 然后检查错误：
          return render_json_error(entry.errors.full_messages.join(", "), status: 422)
        end
      end

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
      render_json_error(e.record.errors.full_messages.join(", "), status: 422)
    rescue ActiveRecord::Rollback => e
      render_json_error(e.message || I18n.t("lottery.errors.transaction_failed"), status: 422) # 事务失败
    rescue StandardError => e
      Rails.logger.error "LotteryPlugin EntriesController Error: #{e.message}\n#{e.backtrace.join("\n")}"
      render_json_error(I18n.t("lottery.errors.generic_error"), status: 500) # 通用错误
    end
  end
end
