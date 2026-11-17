#!/bin/sh
set +x
set -eu
umask 077

REPO='Justinckkk/superset-bi-assistant'
MCP_URL='http://192.168.40.72:15008/mcp'
WEB_URL='http://192.168.40.72:18090'
STATE="$HOME/.local/share/superset-bi-assistant"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CLAUDE_JSON="${CLAUDE_CONFIG_DIR:+$CLAUDE_CONFIG_DIR/.claude.json}"
CLAUDE_JSON="${CLAUDE_JSON:-$HOME/.claude.json}"
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
SKILL="$HOME/.agents/skills/superset-bi"
TEMP=''
TTY_STATE=''

say() { printf '%s\n' "$*"; }
fail() { say "$*" >&2; exit 1; }
quiet() { "$@" </dev/null >/dev/null 2>&1 || fail '操作失败；未显示可能含凭据的 CLI 输出。可重跑修复或卸载。'; }
cleanup() {
    if [ -n "$TTY_STATE" ]; then stty "$TTY_STATE" </dev/tty 2>/dev/null || :; fi
    if [ -n "$TEMP" ]; then rm -rf "$TEMP"; fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

safe_path() {
    candidate=$1
    while [ "$candidate" != / ] && [ "$candidate" != . ]; do
        [ ! -L "$candidate" ] || fail '配置路径含符号链接；为保护其他文件已停止。'
        candidate=$(dirname "$candidate")
    done
}
for target in "$STATE" "$CLAUDE_DIR" "$CLAUDE_JSON" "$CODEX_DIR" "$CODEX_DIR/config.toml" "$SKILL" "$HOME/.local/state/superset-bi-assistant-backups"; do safe_path "$target"; done

has_claude=0
has_codex=0
command -v claude >/dev/null 2>&1 && has_claude=1
command -v codex >/dev/null 2>&1 && has_codex=1

backup() {
    if [ -f "$1" ]; then cp -p "$1" "$BACKUP/$2"; chmod 600 "$BACKUP/$2"; fi
}
fingerprint_codex() { codex mcp get superset --json </dev/null 2>/dev/null | shasum -a 256 | awk '{print $1}'; }
fingerprint_claude() { plutil -extract mcpServers.superset json -o - "$CLAUDE_JSON" 2>/dev/null | shasum -a 256 | awk '{print $1}'; }
make_backup() {
    mkdir -p "$HOME/.local/state/superset-bi-assistant-backups"
    BACKUP=$(mktemp -d "$HOME/.local/state/superset-bi-assistant-backups/change.XXXXXX")
    backup "$CLAUDE_JSON" claude.json
    backup "$CLAUDE_DIR/settings.json" claude-settings.json
    backup "$CLAUDE_DIR/plugins/known_marketplaces.json" known-marketplaces.json
    backup "$CLAUDE_DIR/plugins/installed_plugins.json" installed-plugins.json
    backup "$CODEX_DIR/config.toml" codex-config.toml
}
skill_unchanged() {
    [ -f "$SKILL/.superset-bi-owned" ] || return 1
    [ -z "$(find "$SKILL" -type l -print)" ] || return 1
    expected=$(awk 'END {print NR+1}' "$SKILL/.superset-bi-owned")
    actual=$(find "$SKILL" -type f | wc -l | tr -d ' ')
    [ "$actual" = "$expected" ] || return 1
    (cd "$SKILL" && shasum -a 256 -c .superset-bi-owned </dev/null >/dev/null 2>&1)
}

case "${1:-}" in
    --uninstall)
        [ -f "$STATE/owner" ] || { say '未发现本安装器的记录，无需卸载。'; exit 0; }
        [ "$(cat "$STATE/owner")" = "$REPO" ] || fail '安装来源不同，未删除。'
        TEMP=$(mktemp -d "${TMPDIR:-/tmp}/superset-bi.XXXXXX")
        make_backup
        incomplete=0
        if [ -f "$STATE/claude-mcp" ]; then
            [ "$has_claude" = 1 ] || fail '卸载 Claude 配置需要 claude CLI。'
            if [ "$(fingerprint_claude)" = "$(cat "$STATE/claude-mcp")" ]; then
                quiet claude mcp remove --scope user superset
                if [ -f "$STATE/original-claude.json" ]; then
                    quiet claude mcp add-json --scope user superset "$(cat "$STATE/original-claude.json")"
                fi
                rm "$STATE/claude-mcp"
            else say 'Claude 同名连接已改变，保留；请人工处理。'; incomplete=1; fi
        fi
        if [ -f "$STATE/plugin" ]; then
            quiet claude plugin uninstall --scope user superset-bi@superset-bi
            rm "$STATE/plugin"
        fi
        if [ -f "$STATE/marketplace" ]; then
            quiet claude plugin marketplace remove superset-bi
            rm "$STATE/marketplace"
        fi
        if [ -f "$STATE/codex-mcp" ]; then
            [ "$has_codex" = 1 ] || fail '卸载 Codex 配置需要 codex CLI。'
            if [ "$(fingerprint_codex)" = "$(cat "$STATE/codex-mcp")" ]; then
                quiet codex mcp remove superset
                chmod 600 "$CODEX_DIR/config.toml"
                rm "$STATE/codex-mcp"
            else say 'Codex 同名连接已改变，保留；请人工处理。'; incomplete=1; fi
        fi
        if [ -f "$STATE/skill" ]; then
            if skill_unchanged; then
                rm -rf "$SKILL"
                rm "$STATE/skill"
            else say '技能已改变或来源不明，保留；请人工处理。'; incomplete=1; fi
        fi
        if [ "$incomplete" = 0 ]; then rm -rf "$STATE"; fi
        say '卸载处理完成；未改 shell 配置，安装前备份仍保留在本机。'
        exit "$incomplete"
        ;;
    '') ;;
    *) fail '用法：sh install.sh [--uninstall]' ;;
esac

[ "$has_claude$has_codex" != 00 ] || fail '请先安装 Claude Code 或 Codex CLI，再运行此命令。'
for tool in curl plutil shasum awk mktemp; do command -v "$tool" >/dev/null 2>&1 || fail "缺少工具：${tool}（需要 macOS）。"; done
if [ -e "$STATE" ]; then
    [ -f "$STATE/owner" ] && [ "$(cat "$STATE/owner")" = "$REPO" ] || fail '安装状态来源不明，已停止。'
fi
if [ -e "$SKILL" ] && [ ! -f "$STATE/skill" ]; then fail '已有非本安装器管理的同名技能，未覆盖。'; fi
if [ -e "$SKILL" ] && ! skill_unchanged; then fail '本机技能已手改，未覆盖；请先备份并人工处理。'; fi
if [ -f "$STATE/codex-mcp" ] && [ "$(fingerprint_codex)" != "$(cat "$STATE/codex-mcp")" ]; then
    fail 'Codex 同名连接已手改，未覆盖；请先人工处理。'
fi
if [ -f "$STATE/claude-mcp" ] && [ "$(fingerprint_claude)" != "$(cat "$STATE/claude-mcp")" ]; then
    fail 'Claude 同名连接已手改，未覆盖；请先人工处理。'
fi
if [ "$has_codex" = 1 ] && [ ! -f "$STATE/codex-mcp" ]; then
    if codex mcp get superset --json </dev/null >/dev/null 2>&1; then
        fail 'Codex 已有非本安装器管理的同名连接，未覆盖；请先人工备份和移除。'
    fi
fi
if [ "$has_claude" = 1 ] && [ ! -f "$STATE/plugin" ]; then
    if plutil -extract 'plugins.superset-bi@superset-bi' json -o - "$CLAUDE_DIR/plugins/installed_plugins.json" >/dev/null 2>&1; then
        fail '已有非本安装器管理的同名插件，未覆盖。'
    fi
fi
if [ "$has_claude" = 1 ] && [ ! -f "$STATE/marketplace" ]; then
    if plutil -extract superset-bi json -o - "$CLAUDE_DIR/plugins/known_marketplaces.json" >/dev/null 2>&1; then
        fail '已有非本安装器管理的同名 marketplace，未覆盖。'
    fi
fi

if ! ( : </dev/tty ) 2>/dev/null; then fail '没有交互终端；请在本人终端运行以隐藏输入 Key。'; fi
TTY_STATE=$(stty -g </dev/tty) || fail '无法读取终端状态。'
stty -echo </dev/tty || fail '无法关闭终端回显。'
printf '%s' '个人 MCP Key（隐藏输入，只问一次）：' >/dev/tty
IFS= read -r PERSONAL_KEY </dev/tty || fail '未读到 Key，已取消。'
stty "$TTY_STATE" </dev/tty
TTY_STATE=''
printf '\n' >/dev/tty
case "$PERSONAL_KEY" in ''|*[!A-Za-z0-9._~+/-]*) fail 'Key 为空或含不支持的字符，已取消。';; esac
TEMP=$(mktemp -d "${TMPDIR:-/tmp}/superset-bi.XXXXXX")
printf 'header = "Authorization: Bearer %s"\n' "$PERSONAL_KEY" >"$TEMP/curl.conf"
if status=$(curl -sS --connect-timeout 5 --max-time 12 --config "$TEMP/curl.conf" \
    --header 'Content-Type: application/json' --header 'Accept: application/json, text/event-stream' \
    --data '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"superset-bi-installer","version":"1.0"}}}' \
    -o /dev/null -w '%{http_code}' "$MCP_URL" </dev/null 2>/dev/null); then
    case "$status" in
        401) fail '401：个人 Key 不正确或已失效，请找管理员更换。';;
        403) fail '403：没有访问权限，请找管理员授权。';;
        2??) say 'MCP 最小请求通过。';;
        *) say 'MCP 返回非成功状态，暂未确认认证；继续配置，请检查服务地址。';;
    esac
else
    case "$status" in 401) fail '401：Key 不正确，已停止。';; 403) fail '403：没有权限，已停止。';; esac
    say '连不上 MCP：可能不在办公网；继续安装，恢复网络后重开助手。'
fi
rm "$TEMP/curl.conf"

fetch_skill() {
    relative=$1
    remote=$2
    expected=$3
    mkdir -p "$(dirname "$TEMP/skill/$relative")"
    quiet curl -fsSL --connect-timeout 10 --max-time 60 "https://raw.githubusercontent.com/$REPO/main/$remote" -o "$TEMP/skill/$relative"
    actual=$(shasum -a 256 "$TEMP/skill/$relative" | awk '{print $1}')
    [ "$actual" = "$expected" ] || fail '下载内容与安装器版本不一致；未更改配置，请重新获取安装命令。'
    printf '%s  %s\n' "$expected" "$relative" >>"$TEMP/skill/.superset-bi-owned"
}
if [ "$has_codex" = 1 ]; then
fetch_skill SKILL.md codex/skills/superset-bi/SKILL.md 63848c4400a2fa2aac36714484e0a5d180c6957a6bdba7feca780aa2bb44155b
fetch_skill '事件速查.md' codex/skills/superset-bi/%E4%BA%8B%E4%BB%B6%E9%80%9F%E6%9F%A5.md c0c6538c5f41b70b915d33869893d9da89ce2a76da888a79b062a69ae71fab2f
fetch_skill '直接查询.md' codex/skills/superset-bi/%E7%9B%B4%E6%8E%A5%E6%9F%A5%E8%AF%A2.md 8f760b09968a9931169f409db21f8b136fecf1b144477fd46e47c67e5409fedd
fetch_skill '知识/主题边界.md' codex/skills/superset-bi/%E7%9F%A5%E8%AF%86/%E4%B8%BB%E9%A2%98%E8%BE%B9%E7%95%8C.md ed7ca543d443621fb0b9a16f58467f9265efab44b41db1438a9e5eb21f5c5f95
fetch_skill '知识/分析问法.md' codex/skills/superset-bi/%E7%9F%A5%E8%AF%86/%E5%88%86%E6%9E%90%E9%97%AE%E6%B3%95.md c0edfbff2144fdd094d182262230fc8948fb5621ff53f9136dad9e7ca7bddde9
fetch_skill '知识/报告模板.md' codex/skills/superset-bi/%E7%9F%A5%E8%AF%86/%E6%8A%A5%E5%91%8A%E6%A8%A1%E6%9D%BF.md 1f962571ff3c239c0c177308d9e629cce48f1a53dd54063bc4b651bec8d6f0f7
fetch_skill '知识/指标词典.md' codex/skills/superset-bi/%E7%9F%A5%E8%AF%86/%E6%8C%87%E6%A0%87%E8%AF%8D%E5%85%B8.md 0a593310c2dfaa0497ffe3c65e7e2857ff333a31fa5c7a84c84ca00d225cf1ec
fi

make_backup
mkdir -p "$STATE"
printf '%s\n' "$REPO" >"$STATE/owner"
if [ "$has_claude" = 1 ]; then
    if [ ! -f "$STATE/claude-captured" ]; then
        plutil -extract mcpServers.superset json -o "$TEMP/original.json" "$CLAUDE_JSON" >/dev/null 2>&1 && cp "$TEMP/original.json" "$STATE/original-claude.json"
        : >"$STATE/claude-captured"
    fi
    if [ -f "$STATE/marketplace" ]; then quiet claude plugin marketplace update superset-bi
    else
        quiet claude plugin marketplace add --scope user "$REPO"
        : >"$STATE/marketplace"
    fi
    if [ -f "$STATE/plugin" ]; then quiet claude plugin update --scope user superset-bi@superset-bi
    else
        quiet claude plugin install --scope user superset-bi@superset-bi
        : >"$STATE/plugin"
    fi
    claude mcp remove --scope user superset </dev/null >/dev/null 2>&1 || :
    say 'Claude CLI 的 header 参数会在进程列表短暂可见；只在可信电脑安装。'
    quiet claude mcp add --scope user --transport http superset "$MCP_URL" --header "Authorization: Bearer $PERSONAL_KEY"
    chmod 600 "$CLAUDE_JSON"
    fingerprint_claude >"$STATE/claude-mcp"
    say '已安装 Claude Code 用户级插件、SessionStart 路由提示和 superset HTTP 连接。'
fi
if [ "$has_codex" = 1 ]; then
    mkdir -p "$CODEX_DIR" "$HOME/.agents/skills"
    if [ -f "$STATE/codex-mcp" ]; then quiet codex mcp remove superset; fi
    quiet codex mcp add superset --url "$MCP_URL"
    quiet codex mcp remove superset
    printf '\n[mcp_servers.superset]\nurl = "%s"\n[mcp_servers.superset.http_headers]\nAuthorization = "Bearer %s"\n' "$MCP_URL" "$PERSONAL_KEY" >>"$CODEX_DIR/config.toml"
    chmod 600 "$CODEX_DIR/config.toml"
    fingerprint_codex >"$STATE/codex-mcp"
    if [ -d "$SKILL" ]; then rm -rf "$SKILL"; fi
    mkdir -p "$SKILL"
    cp -R "$TEMP/skill/." "$SKILL/"
    : >"$STATE/skill"
    say '已安装 Codex 用户级 superset-bi 技能和静态 HTTP 头连接；未改 shell 配置。'
fi
unset PERSONAL_KEY
say '完成：在任何文件夹运行 claude 或 codex，直接问：森国昨天的新增是多少。请重开旧会话。'
say "网页：$WEB_URL"
say "更新/换 Key：curl -fsSL https://raw.githubusercontent.com/$REPO/main/install.sh | sh"
say "卸载：curl -fsSL https://raw.githubusercontent.com/$REPO/main/install.sh | sh -s -- --uninstall"
say "本机配置备份：${BACKUP}（含旧凭据，请勿分享）"
