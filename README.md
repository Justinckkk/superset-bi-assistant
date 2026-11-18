# Superset 游戏 BI 助手

先找管理员领取**网页账号、初始密码**。个人 MCP Key 可由管理员一对一代发，也能在网页自己创建（不是网页密码）。有 Claude 桌面 App 就可以安装，不必另装命令行。安装需联网访问 GitHub，问数需在办公网。

**自己创建 Key**：右上角「设置」→「信息」（`/user_info/`）→「API 密钥 / API Keys」→「创建 API 密钥 / Create API Key」，填写名称后创建。明文只显示一次，立即复制供安装时输入；列表只显示自己的记录与前缀，丢失就撤销重建。**改密码**：同页点「重置我的密码 / Reset my password」，填当前密码、新密码和确认密码后保存，再用新密码登录；备用地址为网页地址后的 `/resetmypassword/form`，填写两遍新密码。初始密码改过后不再有效。

**方式一（推荐）：在对话窗口里说一句话**。适用于 Claude Code（桌面 App 的 **Code** 标签页或命令行）和 Codex；Claude 普通聊天和 Cowork 暂不支持。

> 请按 https://raw.githubusercontent.com/Justinckkk/superset-bi-assistant/main/INSTALL.md 的说明在我电脑上安装 Superset 游戏 BI 助手。我的个人 MCP Key 是：<在这里粘贴 Key>

助手会请你允许它运行安装命令，点允许即可；装完它会让你新开一个对话。

**方式二：在 macOS 终端粘贴一条命令**（Key 隐藏输入，只问一次）：

```sh
curl -fsSL https://raw.githubusercontent.com/Justinckkk/superset-bi-assistant/main/install.sh | sh
```

装好后，在助手里**新开一个对话**，直接问：**森国昨天的新增是多少**。
Claude 可显式调用 `/superset-bi:superset-bi`，Codex 可用 `$superset-bi`；重开会话后用 `/skills`、`/mcp` 检查加载与连接。自动触发不是强制安全边界。
仅手工装 Claude 插件（不含 MCP 配置）可用 `/plugin install superset-bi --marketplace Justinckkk/superset-bi-assistant`；完整安装用上面任一方式。

网页：http://192.168.40.72:18090 （用管理员给的网页账号登录）。例如：
- 万灵最近七个完整日的活跃和付费趋势怎么样？
- 风之大陆上周的首充转化率是多少？
- 帮我新建一个森国新增、活跃、收入三图看板。
- 真三国无双9212上周新增人群的7日留存是多少？

**更新 / 换 Key**：再发一次安装句子或重跑终端命令，提供个人 Key 后新开对话。更新不会改你的其他技能和连接。
**卸载**：`curl -fsSL https://raw.githubusercontent.com/Justinckkk/superset-bi-assistant/main/install.sh | sh -s -- --uninstall`，不需要 Key。只移除本安装器管理的内容；原有 Claude 同名用户连接会恢复；Codex 已有非本安装器的同名连接时安装会停止，须先人工备份和移除。后来手改过的连接/技能会保留并提示人工处理。安装前备份保留在用户本机，卸载后不自动删除备份。

**做不到的三件事**：条形图按金额排序、复制官方看板、给图表打标签。请去网页手工操作，不会绕过权限。

**排错**：401 = Key 不对或已失效，找管理员换 Key 后重装；403 = 没有权限，找管理员授权，不要换入口绕过；连不上 = 检查办公网/VPN和地址，离线也可完成本地配置，恢复网络后重开助手。安装失败不要贴配置全文给别人。

**隐私与风险**：贴在对话里的 Key 会留在本机对话记录并发给模型服务商；丢失或不放心，就去网页撤销重建。不愿贴对话可用终端隐藏输入。配置和备份仅限本人读写，不要分享；不改 shell 配置。Claude 安装时 Key 会在进程列表短暂可见，只在可信电脑安装，不开 `set -x`。办公网使用 HTTP，未加密；不要在不可信网络使用。公开仓库不含 Key、账号或名单。
