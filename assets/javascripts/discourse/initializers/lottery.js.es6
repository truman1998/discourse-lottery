import { apiInitializer } from "discourse/lib/api";
import I18n from "I18n"; // 确保导入 I18n
import { h } from "virtual-dom"; // 用于创建元素，或使用 document.createElement

export default apiInitializer("1.0.0", (api) => { // 版本化您的初始化器
  // 使用 Discourse 的模态服务显示警报的辅助函数
  const showAlert = (message, type = 'error') => {
    const modal = api.container.lookup("service:modal");
    if (modal && modal.alert) {
      modal.alert({ message, type }); // type 可以是 'error', 'success', 'warning'
    } else {
      // 针对旧版 Discourse 或模态服务不可用时的回退
      window.alert(message);
    }
  };

  // 更新抽奖框状态显示的函数
  function updateStatusDisplay(box, currentEntries, maxEntries, prizeName, pointsCost) {
    const statusDiv = box.querySelector(".lottery-status-display");
    if (!statusDiv) return;

    let entriesText;
    if (maxEntries && maxEntries > 0) {
      const remaining = Math.max(0, maxEntries - currentEntries);
      entriesText = I18n.t("js.lottery.status_limited", { // 注意：I18n 键保持英文结构
        current: currentEntries,
        total: maxEntries,
        remaining: remaining,
      });
    } else {
      entriesText = I18n.t("js.lottery.status_unlimited", { count: currentEntries });
    }

    const costText = pointsCost > 0 ? I18n.t("js.lottery.cost_info", { cost: pointsCost }) : I18n.t("js.lottery.cost_free");

    // 清除先前的内容并重建
    statusDiv.innerHTML = ''; // 清除现有内容

    const prizeElement = document.createElement("div");
    prizeElement.className = "lottery-prize";
    prizeElement.textContent = I18n.t("js.lottery.prize", { prizeName: prizeName || I18n.t("js.lottery.default_prize") });

    const statsElement = document.createElement("div");
    statsElement.className = "lottery-stats";
    statsElement.textContent = entriesText;

    const costElement = document.createElement("div");
    costElement.className = "lottery-cost";
    costElement.textContent = costText;

    statusDiv.append(prizeElement, statsElement, costElement);
  }


  api.decorateCookedElement((cookedElem, postDecorator) => {
    if (!postDecorator) return; // 确保 postDecorator 可用

    const post = postDecorator.getModel();
    if (!post || !post.id) return; // 确保我们有帖子和帖子 ID

    // 检查此帖子是否具有来自序列化器的抽奖数据
    const lotteryData = post.lottery_data;

    if (lotteryData && lotteryData.id) {
      // 查找或创建抽奖的占位符 div (如果它尚未在已渲染内容中)。
      // 理想情况下，帖子内容 (例如，通过 BBCode) 应已渲染一个占位符 div。
      // 例如: <div class="lottery-container" data-post-id="${post.id}"></div>
      // 我们将查找 .lottery-box 并假定它是目标。
      // 如果未找到，我们可以附加一个，但最好是 HTML 结构已准备好。

      let lotteryBox = cookedElem.querySelector(`.lottery-box[data-lottery-id="${lotteryData.id}"]`);

      // 如果未找到特定的抽奖框，请尝试通用的或创建它。
      // 这部分很棘手：如果 parser.rb 没有注入 .lottery-box，这将找不到任何东西。
      // 让我们假设 .lottery-box *可能* 存在，或者如果我们有 lotteryData 则创建一个。
      if (!lotteryBox) {
         // 尝试查找通用占位符或附加到帖子末尾
         let placeholder = cookedElem.querySelector('.lottery-placeholder-for-post-' + post.id);
         if (!placeholder) {
            // 如果没有特定占位符，则在已渲染内容的末尾创建一个
            placeholder = document.createElement('div');
            placeholder.className = `lottery-box lottery-placeholder-for-post-${post.id}`; // 添加 lottery-box 类
            cookedElem.appendChild(placeholder);
         }
         lotteryBox = placeholder; // 将其用作 lotteryBox
         lotteryBox.dataset.lotteryId = lotteryData.id; // 确保它具有 ID
      }


      // 确保该框尚未初始化
      if (lotteryBox.dataset.lotteryInitialized === "true") return;
      lotteryBox.dataset.lotteryInitialized = "true";

      // 从 lotteryData 填充数据属性 (这些可能会覆盖任何现有的属性)
      lotteryBox.dataset.prizeName = lotteryData.prize_name || I18n.t("js.lottery.default_prize");
      lotteryBox.dataset.pointsCost = lotteryData.points_cost;
      lotteryBox.dataset.maxEntries = lotteryData.max_entries || ""; // 如果为 null/undefined，则为空字符串
      lotteryBox.dataset.totalEntries = lotteryData.total_entries;
      lotteryBox.dataset.lotteryTitle = lotteryData.title || I18n.t("js.lottery.default_title");


      // 清除任何现有内容 (例如，“正在加载抽奖...”)
      lotteryBox.innerHTML = '';

      const lotteryId = lotteryData.id;
      const cost = parseInt(lotteryData.points_cost, 10) || 0;
      const maxEntries = lotteryData.max_entries ? parseInt(lotteryData.max_entries, 10) : null;
      let currentEntries = parseInt(lotteryData.total_entries, 10) || 0;
      const prizeName = lotteryData.prize_name;
      const lotteryTitle = lotteryData.title;


      // 抽奖元素的主容器
      const container = document.createElement("div");
      container.className = "lottery-ui-container";

      // 标题
      const titleElement = document.createElement("h3");
      titleElement.className = "lottery-title-display";
      titleElement.textContent = lotteryTitle || I18n.t("js.lottery.default_title");
      container.appendChild(titleElement);

      // 状态显示区域
      const statusDisplay = document.createElement("div");
      statusDisplay.className = "lottery-status-display";
      container.appendChild(statusDisplay);

      // 初始状态更新
      updateStatusDisplay(lotteryBox, currentEntries, maxEntries, prizeName, cost);


      // 参与按钮
      const button = document.createElement("button");
      button.className = "btn btn-primary join-lottery-btn";
      button.innerHTML = cost > 0
        ? I18n.t("js.lottery.participate_with_cost_btn", { cost })
        : I18n.t("js.lottery.participate_btn");

      // 如果抽奖已满且设置了 maxEntries，则禁用按钮
      if (maxEntries && currentEntries >= maxEntries) {
        button.disabled = true;
        button.innerHTML = I18n.t("js.lottery.max_entries_reached_btn");
      }

      // 用于反馈的消息区域
      const messageArea = document.createElement("div");
      messageArea.className = "lottery-message-area";
      container.appendChild(messageArea);


      button.addEventListener("click", async () => {
        if (cost > 0) {
          const modal = api.container.lookup("service:modal");
          // 使用确认模态框处理积分消耗
          modal.confirm({
            message: I18n.t("js.lottery.confirm_cost_participation", { cost }),
            didConfirm: async () => {
              await tryJoinLottery();
            }
          });
        } else {
          await tryJoinLottery();
        }
      });

      async function tryJoinLottery() {
        button.disabled = true;
        messageArea.textContent = I18n.t("js.lottery.joining");
        messageArea.className = "lottery-message-area lottery-processing";


        try {
          const csrfToken = api.container.lookup("service:csrf-token");
          if (!csrfToken || !csrfToken.token) {
            // 这个错误消息最好也通过 I18n 处理，但为简单起见，暂时保留英文
            throw new Error("CSRF token not found.");
          }

          const response = await fetch("/lottery_plugin/entries", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "X-CSRF-Token": csrfToken.token,
            },
            body: JSON.stringify({ lottery_id: lotteryId }),
          });

          const data = await response.json();

          if (response.ok && data.success) {
            showAlert(data.message || I18n.t("js.lottery.success_joined_alert"), 'success');
            currentEntries = data.total_entries; // 从响应更新当前参与人数
            lotteryBox.dataset.totalEntries = currentEntries; // 更新数据属性
            updateStatusDisplay(lotteryBox, currentEntries, maxEntries, prizeName, cost);

            // 如果抽奖变满，则禁用按钮
            if (maxEntries && currentEntries >= maxEntries) {
              button.disabled = true;
              button.innerHTML = I18n.t("js.lottery.max_entries_reached_btn");
            } else {
               // 如果需要，可以更新按钮文本，例如“您已参与”
               // 目前保持原样，或者如果用户已参与则禁用 (服务器应阻止重复参与)
            }
            messageArea.textContent = I18n.t("js.lottery.success_message_inline");
            messageArea.className = "lottery-message-area lottery-success";

          } else {
            // 处理来自服务器的错误 (例如，校验失败、积分不足)
            // 注意：这里的 I18n.t 使用的是服务器端 YAML 文件中的键
            const errorMessage = data.error || (data.errors && data.errors.join(", ")) || I18n.t("lottery.errors.generic_error");
            showAlert(errorMessage, 'error');
            messageArea.textContent = errorMessage;
            messageArea.className = "lottery-message-area lottery-error";
            button.disabled = false; // 失败时重新启用按钮
          }
        } catch (e) {
          console.error("Lottery Plugin JS Error:", e);
          // 注意：这里的 I18n.t 使用的是服务器端 YAML 文件中的键
          const networkErrorMsg = I18n.t("lottery.errors.network_error");
          showAlert(networkErrorMsg + (e.message ? ` (${e.message})` : ''), 'error');
          messageArea.textContent = networkErrorMsg;
          messageArea.className = "lottery-message-area lottery-error";
          button.disabled = false; // 网络/意外错误时重新启用按钮
        }
      }

      // 将 UI 元素附加到抽奖框
      lotteryBox.appendChild(container);
      if (! (maxEntries && currentEntries >= maxEntries) ) { // 仅当尚未满员时添加按钮
        container.appendChild(button);
      }
      container.appendChild(messageArea); // 消息区域在按钮之后

    } // 结束 if (lotteryData)
  }, {
    id: 'discourse-lottery-decorator', // 修饰器的唯一 ID
    onlyStream: true // 仅应用于帖子流 (主题视图)
  });
});
