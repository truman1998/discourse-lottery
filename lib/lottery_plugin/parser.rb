# frozen_string_literal: true

module LotteryPlugin
  module Parser
    # 这是解析逻辑的占位符。
    # 在实际的插件中，这将解析帖子内容 (例如 doc)
    # 以查找特定的 BBCode 或 Markdown 模式来创建抽奖。
    #
    # BBCode 示例: [lottery title="赢取T恤" prize="酷炫T恤" cost="10" max_entries="50"]
    #
    # 参数:
    # - post: 正在处理的 Post 对象。
    # - doc: 一个 Nokogiri::HTML::DocumentFragment，表示已渲染的帖子内容。
    def self.parse(post, doc)
      # 例如，仅处理主题的第一个帖子以创建抽奖。
      # 或者，如果期望的行为是允许在任何帖子中创建抽奖，则修改此逻辑。
      return unless post.post_number == 1 # 示例：仅允许在第一个帖子中创建抽奖

      # 检查此帖子是否已存在抽奖，以防止在多次保存或重复处理时产生重复。
      return if Lottery.exists?(post_id: post.id)

      # --- 实际解析逻辑的占位符 ---
      # 您需要定义如何在帖子中指定抽奖。
      # 例如，查找自定义 BBCode 或特定的 HTML 结构。

      # 示例：查找具有特定类且包含抽奖数据属性的 div。
      # 这假设帖子内容以某种方式包含类似以下的元素：
      # <div class="lottery-definition"
      #      data-title="我的超赞抽奖"
      #      data-prize="一个奇妙的奖品"
      #      data-cost="10"
      #      data-max-entries="100">
      # </div>
      #
      # 注意：这种直接在 HTML 中嵌入数据供服务器端解析的方法
      # 不如使用 BBCode（由 Discourse 转换为 HTML）常见。
      # BBCode 方法将涉及服务器端 BBCode 处理器。

      # 目前，我们假设在这个基本版本中，我们不通过帖子内容解析来创建抽奖，
      # 抽奖是通过其他机制创建的（例如，管理界面或更复杂的解析器）。
      # 如果当帖子包含 `[lottery-placeholder]` 时创建抽奖，
      # 那么您将搜索该占位符。

      # 让我们模拟找到一个占位符并创建一个默认抽奖。
      # 这是一个非常基础的示例。
      if doc.text.include?("[在此创建抽奖]") # 简单的文本触发器
        begin
          Lottery.create!(
            post_id: post.id,
            topic_id: post.topic_id,
            title: "帖子 #{post.id} 的示例抽奖",
            prize_name: "一份惊喜奖品!",
            points_cost: 5, # 默认消耗
            max_entries: 50   # 默认最大参与人数
          )
          Rails.logger.info "LotteryPlugin: 为帖子 #{post.id} 创建了一个示例抽奖"
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "LotteryPlugin: 为帖子 #{post.id} 创建抽奖失败。错误: #{e.record.errors.full_messages.join(", ")}"
        rescue => e
          Rails.logger.error "LotteryPlugin: 为帖子 #{post.id} 创建抽奖时发生意外错误。错误: #{e.message}"
        end
      end

      # --- 占位符结束 ---

      # 如果您正在修改 'doc' (已渲染的 HTML)，请务必小心处理。
      # 例如，如果您将 [lottery] BBCode 替换为实际的抽奖 UI 占位符：
      # doc.css('div.lottery-bbcode-placeholder').each do |el|
      #   lottery = Lottery.find_by(post_id: post.id) # 假设它已被创建
      #   if lottery
      #     # 用抽奖框的 HTML 结构替换 'el'
      #     # 然后，此 HTML 将由 JavaScript 初始化器修饰
      #     lottery_box_html = render_lottery_box_placeholder(lottery)
      #     el.replace(lottery_box_html)
      #   end
      # end
    end

    # 生成抽奖框占位符 HTML 的辅助方法
    # 此 HTML 结构将被您的 JavaScript 初始化器拾取
    # def self.render_lottery_box_placeholder(lottery)
    #   <<~HTML
    #     <div class="lottery-box"
    #          data-lottery-id="#{lottery.id}"
    #          data-prize-name="#{CGI.escapeHTML(lottery.prize_name)}"
    #          data-points-cost="#{lottery.points_cost}"
    #          data-max-entries="#{lottery.max_entries || ''}"
    #          data-total-entries="#{lottery.entries.count}"
    #          data-lottery-title="#{CGI.escapeHTML(lottery.title)}">
    #       #       <p>正在加载抽奖...</p>
    #     </div>
    #   HTML
    # end
    #
    # 重要提示：当前的 `plugin.rb` 使用 `add_to_serializer` 将抽奖数据传递给前端。
    # 然后，JavaScript 会查找 `.cooked .lottery-box` 元素，
    # 如果帖子存在抽奖，则假定这些元素是帖子 HTML 的一部分。
    # `parser.rb` 将负责确保如果为该帖子定义了抽奖，
    # 则帖子的已渲染 HTML 中存在这样一个 `.lottery-box` div
    # (或类似的可识别元素)。
    #
    # 一种常见的模式：
    # 1. 用户在其帖子中包含 `[lottery name="我的奖品" ...]`。
    # 2. BBCode 处理器 (在 `plugin.rb` 或此处定义) 将其转换为：
    #    `<div class="lottery-container" data-lottery-post-id="#{post.id}"></div>`
    #    并在数据库中创建 `LotteryPlugin::Lottery` 记录。
    # 3. 然后，`lottery.js.es6` 初始化器找到 `.lottery-container`，使用
    #    `post-id` 从 `post_stream.posts.lottery_data`
    #    (由序列化器添加) 获取完整的抽奖详细信息，或者如果需要，则进行单独的 API 调用，
    #    然后构建交互式 UI。
    #
    # 当前的 `lottery.js.es6` 期望带有数据属性的 `lottery-box`。
    # 因此，如果创建了抽奖 (例如，通过此解析器或其他机制)，
    # 请确保帖子的已渲染 HTML 包含类似以下的 div：
    # <div class="lottery-box" data-lottery-id="抽奖的ID"></div>
    # 然后，JS 初始化器将使用此 ID。`plugin.rb` 中的序列化器
    # 如果帖子的 Lottery 记录存在，则已提供大部分必要数据。
    # JS 可以使用 `api.getPost(postId)` 或序列化数据。

    # 目前，此解析器不修改 `doc`。它仅尝试创建抽奖。
    # JavaScript 将依赖于序列化器注入的数据，并寻找
    # 一种通用的方式来识别如果帖子具有 lottery_data，则在何处放置抽奖 UI。
    # 当前的 JS (`lottery.js.es6`) 会修饰它找到的 `.lottery-box` 元素。
    # 因此，如果抽奖与其关联并且您希望 JS 拾取它，
    # 您的帖子内容 *必须* 包含 `<div class="lottery-box" data-lottery-id="..."></div>`。
    # 如果定义/创建了抽奖，此 `parser.rb` 将是注入此类 div 的地方。

    # 现在，让我们假设如果为帖子创建了 Lottery 记录，
    # 帖子的模板或 BBCode 渲染已经输出：
    # <div class="lottery-box" data-lottery-id="<%= lottery.id %>" ... (其他数据属性) ... ></div>
    # 这是用户提供的当前代码中的一个空白 —— .lottery-box div 如何进入帖子。
    # 一种简单的方法是让用户手动放置：
    # `[wrap=lottery-box data-lottery-id=手动ID]抽奖内容[/wrap]`
    # 或者，一个扩展为此的 BBCode。
  end
end
