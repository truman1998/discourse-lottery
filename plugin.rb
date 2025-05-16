# name: discourse-lottery
# about: 一个在 Discourse 帖子中创建抽奖的插件。
# version: 1.0.3
# authors: 您的名字 (例如, Truman)
# url: https://github.com/truman1998/discourse-lottery
# required_version: 2.8.0.beta10

enabled_site_setting :lottery_enabled # 启用抽奖插件的站点设置

register_asset "stylesheets/common/lottery.scss"

after_initialize do
  begin # 添加 begin-rescue 块来捕获初始化期间的潜在错误
    # 定义插件的 Rails 引擎
    module ::LotteryPlugin
      PLUGIN_NAME ||= "discourse-lottery".freeze

      class Engine < ::Rails::Engine
        engine_name PLUGIN_NAME
        isolate_namespace LotteryPlugin
      end
    end

    # 加载模型文件
    require_relative "app/models/lottery_plugin/lottery"
    require_relative "app/models/lottery_plugin/lottery_entry"

    # 加载库文件
    require_relative "lib/lottery_plugin/parser"

    # 处理帖子的事件监听器
    DiscourseEvent.on(:post_process_cooked) do |doc, post|
      begin
        if SiteSetting.lottery_enabled && post && doc
          # Rails.logger.info "LotteryPlugin: [Event :post_process_cooked] Processing post ID #{post.id}."
          LotteryPlugin::Parser.parse(post, doc)
        end
      rescue => e
        Rails.logger.error "LotteryPlugin: [Event :post_process_cooked] Error processing post ID #{post&.id}. Error: #{e.class.name} - #{e.message}\nBacktrace: #{e.backtrace.take(10).join("\n")}"
      end
    end

    # 加载控制器文件
    require_dependency File.expand_path("../app/controllers/lottery_plugin/entries_controller.rb", __FILE__)

    # 定义插件路由
    LotteryPlugin::Engine.routes.draw do
      post "/entries" => "entries#create"
    end

    # 将插件的引擎挂载到主 Discourse 应用的路由中
    Discourse::Application.routes.append do
      mount ::LotteryPlugin::Engine, at: "/lottery_plugin"
    end

    # 向帖子序列化器添加数据
    add_to_serializer(:post, :lottery_data, false) do
      begin
        # Rails.logger.info "LotteryPlugin Serializer: Checking post ID #{object.id}"
        lottery = LotteryPlugin::Lottery.find_by(post_id: object.id)
        if lottery
          # Rails.logger.info "LotteryPlugin Serializer: Found lottery ##{lottery.id} for post #{object.id}"
          {
            id: lottery.id,
            title: lottery.title,
            prize_name: lottery.prize_name,
            points_cost: lottery.points_cost,
            max_entries: lottery.max_entries,
            total_entries: lottery.entries.count,
          }
        else
          # Rails.logger.info "LotteryPlugin Serializer: No lottery found for post #{object.id}"
          nil
        end
      rescue => e
        Rails.logger.error "LotteryPlugin Serializer: Error for post ID #{object&.id}. Error: #{e.class.name} - #{e.message}\nBacktrace: #{e.backtrace.take(10).join("\n")}"
        nil # 在序列化器中出错时返回 nil，以避免破坏整个帖子流
      end
    end
  rescue => e # 捕获 after_initialize 块中的任何错误
    Rails.logger.error "LotteryPlugin: FATAL ERROR during after_initialize. Plugin may not be fully functional. Error: #{e.class.name} - #{e.message}\nBacktrace: #{e.backtrace.join("\n")}"
  end
end
