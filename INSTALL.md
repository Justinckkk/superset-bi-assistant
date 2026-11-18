# 给 AI 助手的安装说明

这是 Superset 游戏 BI 助手。安装器为本机用户添加 Claude Code 插件或 Codex 技能、名为 `superset` 的 MCP 连接，以及状态目录 `~/.local/share/superset-bi-assistant` 和备份目录 `~/.local/state/superset-bi-assistant-backups`。

1. 确认自己运行在 Claude Code（桌面 App 的 **Code** 标签页或命令行）或 Codex 中，并能在用户本机执行 shell。Claude 普通聊天和 Cowork 不读取这份本机配置，请用户切到 Code。Codex 安装器需要 PATH 中有 `codex`，不自动查找桌面 App 自带程序。
2. 用户已给个人 MCP Key 就直接用；否则只问一次。它是登录 Superset 网页后在「设置 → 信息 → API 密钥」创建的，不是网页密码。
3. 在本机执行下面的命令，把占位符替换成用户给的 Key（只接受字母、数字和 `._~+/-`，不合格就不要拼入命令）。Key 传给 `sh`，不要传给 `curl`。不要把含 Key 的命令发回对话或留在终端历史；工具支持为子进程注入环境变量时，优先用它注入并将赋值写成 `SUPERSET_BI_KEY="$SUPERSET_BI_KEY"`。

   ```sh
   (
     set +x
     installer=$(unset SUPERSET_BI_KEY; curl -fsSL https://raw.githubusercontent.com/Justinckkk/superset-bi-assistant/main/install.sh) &&
       printf '%s\n' "$installer" | SUPERSET_BI_KEY='<个人 MCP Key>' /bin/sh
   )
   ```

4. 以退出码为 0 且有「完成」提示为本机安装成功。若需核对连接，使用 PATH 中的 `claude`、桌面内置的同一程序（如 `"$CLAUDE_CODE_EXECPATH"`）或 `codex` 执行 `mcp get superset >/dev/null 2>&1`，只看退出码，不展示配置；连通状态在新对话用 `/mcp` 查看。告诉用户**新开一个对话**再问数。
5. 401：Key 不对或已失效，请网页撤销重建或联系管理员；403：找管理员授权，不绕过；连不上：说明本机配置可完成，但要检查办公网/VPN 和地址，恢复后再新开对话。其他失败只转述不含凭据的提示，不复述 Key、不另存明文、不改 shell 配置、不贴配置全文。
