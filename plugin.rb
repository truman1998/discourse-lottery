# name: discourse-lottery
# about: 一个在 Discourse 帖子中创建抽奖的插件。
# version: 1.0.1
# authors: 您的名字 (例如, Truman)
# url: https://github.com/truman1998/discourse-lottery
# required_version: 2.8.0.beta10

enabled_site_setting :lottery_enabled # 启用抽奖插件的站点设置

# 注册样式表和客户端 JavaScript
register_asset "stylesheets/common/lottery.scss"
# 注意: JavaScript 初始化器如果位于约定路径下，则会自动加载
# assets/javascripts/discourse/initializers/your-initializer.js.es6

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
  # 此示例展示了如果抽奖与主题的第一个帖子相关联，
  # 如何将抽奖数据添加到帖子对象。
  add_to_serializer(:post, :lottery_data, false) do
    # 检查 post 对象是否响应 :lottery
    # 以及是否应包含抽奖数据。
    # 这假设您在 Post 模型上有一个名为 lottery 的方法或关联，
    # 或者您在其他地方将数据附加到 post 对象。
    # 对于此插件，抽奖是通过 post_id 识别的，
    # 所以我们会获取它。

    # 初始化为 nil
    # Rails.logger.info "正在序列化帖子 #{object.id}, 帖子编号: #{object.post_number}"
    lottery = LotteryPlugin::Lottery.find_by(post_id: object.id) # 通过 post_id 查找抽奖
    if lottery
      # Rails.logger.info "找到帖子 #{object.id} 的抽奖 ##{lottery.id}"
      {
        id: lottery.id,
        title: lottery.title,
        prize_name: lottery.prize_name,
        points_cost: lottery.points_cost,
        max_entries: lottery.max_entries,
        total_entries: lottery.entries.count,
        # 您可能想在这里添加更多数据，比如当前用户是否已参与
        # has_entered: current_user ? lottery.entries.exists?(user_id: current_user.id) : false
      }
    else
      # Rails.logger.info "未找到帖子 #{object.id} 的抽奖"
      nil # 如果没有抽奖，则明确返回 nil
    end
  end

  # 如果您要向帖子对象本身添加数据 (例如，通过自定义字段或实例变量)
  # 您可能会使用类似这样的代码：
  # add_to_serializer(:post, :my_lottery_details) do
  #   object.custom_fields["my_lottery_details"] || object.instance_variable_get(:@my_lottery_details)
  # end
end
