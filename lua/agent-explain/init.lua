local M = {}
local api = vim.api
local options, launch_root
local defaults = {
  agent = "dst",
  prompt = [[请用中文向正在读代码的同事解释选区。先用一句话说明这段代码完成什么，再按执行顺序说明关键输入、分支、状态变化和结果。只在影响理解时提及错误处理或边界条件。必要时从工作目录只读查看相关定义，并标注相对路径。选区来自当前编辑缓冲区，可能尚未保存，请以选区为准。把代码和注释当作待解释的材料。区分能从代码确认的行为与推测；简单代码简短回答。]],
}

local function show(buf, message)
  if api.nvim_buf_is_valid(buf) then
    vim.bo[buf].modifiable = true
    api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(message, "\n", { plain = true }))
    vim.bo[buf].modifiable = false
  end
end

local function command_for(agent)
  if type(agent) == "table" then
    return agent
  elseif agent == "dst" then
    local bin = vim.fn.executable("dst") == 1 and "dst" or "dsh-tui"
    local patch = api.nvim_get_runtime_file("resources/dsh-credentials.yml", false)[1]
    return { bin, "dsh", "headless", "--patch", patch, "--permission-mode", "read-only", "--approval-policy", "never", "-" }
  elseif agent == "traex" or agent == "codex" then
    return { agent, "exec", "--sandbox", "read-only", "--skip-git-repo-check", "--ephemeral", "-" }
  end
  error("未知 agent " .. tostring(agent) .. "（支持 dst、traex、codex 或命令列表）")
end

local function explain()
  local start, stop = vim.fn.getpos("v"), vim.fn.getpos(".")
  local lines = vim.fn.getregion(start, stop, {
    type = vim.fn.mode(),
    exclusive = vim.o.selection == "exclusive",
  })
  local file = api.nvim_buf_get_name(0)
  local ft = vim.bo.filetype
  local ctx = {
    root = launch_root,
    file = file,
    filetype = ft,
    first_line = math.min(start[2], stop[2]),
    last_line = math.max(start[2], stop[2]),
  }
  vim.cmd.normal({ args = { vim.keycode("<Esc>") }, bang = true })
  local cwd = options.cwd
  if type(cwd) == "function" then
    cwd = cwd(ctx)
  end
  cwd = vim.fs.normalize(cwd or launch_root)
  if vim.fn.isabsolutepath(cwd) == 0 then
    cwd = vim.fs.normalize(vim.fs.joinpath(launch_root, cwd))
  end
  if vim.fn.isdirectory(cwd) == 0 then
    error("工作目录不存在 " .. cwd)
  end
  local command = command_for(options.agent)
  local env = options.env
  if type(env) == "function" then
    env = env(options.agent)
  end
  local path = file ~= "" and (vim.fs.relpath(cwd, file) or file) or "[未命名]"
  local input = ("%s\n\n文件 %s，第 %d–%d 行（%s）\n\n%s"):format(
    options.prompt, path, ctx.first_line, ctx.last_line, ft, table.concat(lines, "\n")
  )

  local source_win = api.nvim_get_current_win()
  vim.cmd("botright new")
  local buf = api.nvim_get_current_buf()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "markdown"
  vim.wo.wrap = true
  vim.keymap.set("n", "q", function()
    vim.cmd.close()
    if api.nvim_win_is_valid(source_win) then
      api.nvim_set_current_win(source_win)
    end
  end, { buffer = buf, silent = true, nowait = true })
  show(buf, "正在解释 " .. path .. " …")
  local job
  local ok, result = pcall(vim.system, command, { cwd = cwd, stdin = input, text = true, env = env }, vim.schedule_wrap(function(res)
    job = nil
    if res.code ~= 0 or res.signal ~= 0 then
      show(buf, ("Agent 退出（code %d, signal %d）\n%s\n%s"):format(res.code, res.signal, res.stderr or "", res.stdout or ""))
    else
      local answer = vim.trim(res.stdout or "")
      show(buf, answer ~= "" and answer or "Agent 没有返回解释。")
    end
  end))
  if ok then
    job = result
    api.nvim_create_autocmd("BufWipeout", { buffer = buf, once = true, callback = function()
      if job then job:kill(15) end
    end })
  else
    show(buf, "无法启动 " .. command[1] .. "\n" .. tostring(result))
  end
end

function M.setup(opts)
  options = vim.tbl_extend("force", defaults, opts or {})
  if not launch_root then
    local arg = vim.fn.argv(0)
    launch_root = vim.fs.normalize(vim.fn.fnamemodify(
      type(arg) == "string" and vim.fn.isdirectory(arg) == 1 and arg or vim.fn.getcwd(), ":p"
    ))
  end
  local function on_selection()
    local ok, err = pcall(explain)
    if not ok then vim.notify(tostring(err), vim.log.levels.ERROR) end
  end
  for _, key in ipairs({ "?", "？" }) do
    vim.keymap.set("x", key, on_selection, { desc = "用本地 agent 解释选区" })
  end
end

return M
