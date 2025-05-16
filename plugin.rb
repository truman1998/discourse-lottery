# name: discourse-lottery
# about: 一个在 Discourse 帖子中创建抽奖的插件。
# version: 1.0.2
# authors: truman1998
# url: https://github.com/truman1998/discourse-lottery
# required_version: 2.8.0.beta10

enabled_site_setting :lottery_enabled # 启用抽奖插件的站点设置

# 注册样式表和客户端 JavaScript
register_asset "stylesheets/common/lottery.scss"

after_initialize do
  # 定义插件的 Rails 引擎
  module ::LotteryPlugin
    PLUGIN_NAME ||= "discourse-lottery".freeze # 定义插件名称常量

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME # 设置引擎名称
      isolate_namespace LotteryPlugin # 确保路由和模型具有命名空间
    end
  end

  # 加载模型文件
  # 确保路径相对于插件的根目录
  require_relative "app/models/lottery_plugin/lottery"
  require_relative "app/models/lottery_plugin/lottery_entry"

  # 加载库文件
  require_relative "lib/lottery_plugin/parser"

  # 处理帖子的事件监听器
  # 这是您集成抽奖创建逻辑的地方
  DiscourseEvent.on(:post_process_cooked) do |doc, post|
    if SiteSetting.lottery_enabled # 检查插件是否已启用
      # 确保 post 对象不为 nil 且有内容
      if post && doc
        # Rails.logger.info "LotteryPlugin: Processing post ID #{post.id} with parser."
        LotteryPlugin::Parser.parse(post, doc) # 调用解析器处理帖子
      end
    end
  end

  # 加载控制器文件
  # 在 Discourse 中，对控制器使用 require_dependency 是一种常见做法
  # 以确保它们在开发模式下无需重启服务器即可重新加载。
  require_dependency File.expand_path("../app/controllers/lottery_plugin/entries_controller.rb", __FILE__)

  # 定义插件路由
  LotteryPlugin::Engine.routes.draw do
    post "/entries" => "entries#create" # 创建参与记录的路由
  end

  # 将插件的引擎挂载到主 Discourse 应用的路由中
  Discourse::Application.routes.append do
    mount ::LotteryPlugin::Engine, at: "/lottery_plugin" # 插件的基础路径
  end

  # 如果需要，向帖子序列化器添加数据
  add_to_serializer(:post, :lottery_data, false) do
    # Rails.logger.info "LotteryPlugin Serializer: Checking post ID #{object.id}"
    lottery = LotteryPlugin::Lottery.find_by(post_id: object.id) # 通过 post_id 查找抽奖
    if lottery
      # Rails.logger.info "LotteryPlugin Serializer: Found lottery ##{lottery.id} for post #{object.id}"
      {
        id: lottery.id,
        title: lottery.title,
        prize_name: lottery.prize_name,
        points_cost: lottery.points_cost,
        max_entries: lottery.max_entries,
        total_entries: lottery.entries.count,
        # has_entered: current_user ? lottery.entries.exists?(user_id: current_user.id) : false # 示例：检查用户是否已参与
      }
    else
      # Rails.logger.info "LotteryPlugin Serializer: No lottery found for post #{object.id}"
      nil # 如果没有抽奖，则明确返回 nil
    end
  end
end
