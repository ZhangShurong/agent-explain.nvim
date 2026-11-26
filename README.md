# agent-explain.nvim

在 Neovim 0.11+ 中用本地 coding agent 解释当前选区。按 `v`、`V` 或 `Ctrl-v` 选择代码，再按 `?` 或 `？`。解释显示在下方的 Markdown 窗口，按 `q` 关闭。请求在后台运行，关闭结果缓冲区会向运行中的 agent 发送终止信号。

## LazyVim 安装

将以下配置保存到 `lua/plugins/agent-explain.lua`，重启 Neovim。

```lua
return {
  {
    "ZhangShurong/agent-explain.nvim",
    main = "agent-explain",
    lazy = false,
    opts = {},
  },
}
```

## 配置

默认调用 `dst dsh headless --permission-mode read-only --approval-policy never -`。找不到 `dst` 时调用同一工具的 `dsh-tui` 入口。插件通过随附的 DSH patch 启用本机凭据服务，以便 headless profile 使用已保存的 DeepSeek 登录凭据或环境变量。TraeX 和 Codex 使用各自的本机登录与模型设置，以只读、一次性会话运行，也支持在 Git 仓库之外使用。插件通过标准输入发送提示词、文件名、行号及当前缓冲区的选区，从标准输出读取回答。

默认工作目录取启动时的第一个目录参数。例如 `nvim ./oec/` 打开后，即使正在查看 `oec/seller_im_card/main.go`，agent 仍在 `oec` 中运行。首个参数为文件或没有参数时，使用插件启动时的工作目录。保持 `lazy = false` 以便在启动时记录目录。

以下选项都可以独立放入 `opts`。

```lua
opts = {
  agent = "dst", -- 也可以选 "traex" 或 "codex"
  prompt = "用中文说明这段代码的目的、关键分支和副作用。必要时读取相关定义。",
  cwd = "..",
}
```

`agent` 可选择预设，也可以是可执行文件及参数的列表，替代 agent 应能从标准输入读取请求并向标准输出写入答复。`cwd` 支持绝对路径、相对于启动项目的路径，或返回目录的 Lua 函数。函数接收含 `root`、`file`、`filetype`、`first_line`、`last_line` 的表。

如需为子进程覆盖环境变量，设置 `env = { ... }`，或提供接收 agent 配置并返回环境变量表的函数。
