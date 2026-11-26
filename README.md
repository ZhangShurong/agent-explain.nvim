# agent-explain.nvim

在 Neovim 0.11+ 中用本地 coding agent 解释当前选区。按 `v`、`V` 或 `Ctrl-v` 选择代码，再按 `?` 或 `？`。插件会在居中的终端悬浮窗里启动 agent 自带的交互界面，并提交原选区作为第一条消息。直接输入问题并回车即可在同一会话追问。按 `Ctrl+E` 结束当前 agent 进程并回到代码。下次选中代码按 `?` 会启动新的会话。

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

默认在终端中打开本机 Codex。三个内置预设（`codex`、`dst`、`traex`）均以只读设置启动，并沿用各自的登录与模型配置。首次启动可能显示 CLI 自带的登录或工作目录信任提示。首条消息包含提示词、文件名、行号和当前缓冲区的选区。超过 96 KiB 或含 NUL 的请求通过临时快照传递，关闭窗口后删除。

默认工作目录取启动时的第一个目录参数。例如 `nvim ./oec/` 打开后，即使正在查看 `oec/seller_im_card/main.go`，agent 仍在 `oec` 中运行。首个参数为文件或没有参数时，使用插件启动时的工作目录。保持 `lazy = false` 以便在启动时记录目录。

以下选项都可以独立放入 `opts`。

```lua
opts = {
  ui = "native", -- 原生终端界面；"markdown" 使用插件的问答窗口
  agent = "codex", -- 也可以选 "dst" 或 "traex"
  prompt = "用中文说明这段代码的目的、关键分支和副作用。必要时读取相关定义。",
  cwd = "..",
}
```

`agent` 可选择预设，也可以是可执行文件及参数的列表。自定义命令列表默认使用 Markdown 模式，通过标准输入输出交换文本；显式配置 `ui = "native"` 时，列表应启动交互 CLI，插件将首条消息追加为最后一个参数。Markdown 窗口中按 `f` 追问，按 `Ctrl+E` 或 `q` 关闭。`cwd` 支持绝对路径、相对于启动项目的路径，或返回目录的 Lua 函数。函数接收含 `root`、`file`、`filetype`、`first_line`、`last_line` 的表。

如需为子进程覆盖环境变量，设置 `env = { ... }`，或提供接收 agent 配置并返回环境变量表的函数。
