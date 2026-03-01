local M = {}

M.win = nil
M.buf = nil
M.callbacks = {}

function M.toggle(state, config, callbacks)
  M.callbacks = callbacks
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    vim.api.nvim_win_close(M.win, true)
    M.win = nil
    return
  end
  M.create_window(state, config)
  M.render(state, config)
end

function M.create_window(state, config)
  local width = math.min(60, vim.o.columns - 4)
  local height = math.min(20, vim.o.lines - 4)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  M.buf = vim.api.nvim_create_buf(false, true)
  M.win = vim.api.nvim_open_win(M.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  })

  vim.api.nvim_buf_set_option(M.buf, "filetype", "session_todo")
  vim.api.nvim_buf_set_option(M.buf, "modifiable", false)

  vim.keymap.set("n", "q", function()
    if M.win and vim.api.nvim_win_is_valid(M.win) then
      vim.api.nvim_win_close(M.win, true)
      M.win = nil
    end
  end, { buffer = M.buf, noremap = true })

  vim.keymap.set("n", "<cr>", function()
    local cursor = vim.api.nvim_win_get_cursor(M.win)
    local line = cursor[1]
    if line >= 3 and line <= 2 + #state.tasks then
      M.callbacks.on_select(line - 2)
    end
  end, { buffer = M.buf, noremap = true })

  vim.keymap.set("n", " ", function()
    local cursor = vim.api.nvim_win_get_cursor(M.win)
    local line = cursor[1]
    if line >= 3 and line <= 2 + #state.tasks then
      M.callbacks.on_toggle_task(line - 2)
    end
  end, { buffer = M.buf, noremap = true })

  vim.keymap.set("n", "<leader>s", function()
    if state.timer_running then
      M.callbacks.on_stop_timer()
    else
      M.callbacks.on_start_timer()
    end
  end, { buffer = M.buf, noremap = true })
end

function M.render(state, config)
  if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
    return
  end

  local lines = {}
  local hl = {}

  local session_indicator = state.session_type == "work" and "Work" or "Break"
  table.insert(lines, " SessionTodo: " .. session_indicator .. " ")
  table.insert(hl, "Title")

  if state.timer_running then
    local task = state.tasks[state.current_task_idx]
    if task then
      local remaining = task.duration - task.elapsed
      local mins = math.floor(remaining / 60)
      local secs = remaining % 60
      table.insert(lines, string.format(" ⏱ %02d:%02d - %s", mins, secs, task.text))
      table.insert(hl, "TimerRunning")
    end
  else
    table.insert(lines, " Press <leader>s to start timer ")
    table.insert(hl, "Normal")
  end

  table.insert(lines, "")
  table.insert(lines, " Tasks (Enter to select, Space to toggle):")
  table.insert(hl, "Normal")

  for i, task in ipairs(state.tasks) do
    local status = task.done and "[x]" or "[ ]"
    local prefix = i == state.current_task_idx and ">" or " "
    local elapsed = math.floor(task.elapsed / 60)
    table.insert(lines, string.format("%s %s %s (%dm)", prefix, status, task.text, elapsed))
    if i == state.current_task_idx then
      table.insert(hl, "Selected")
    elseif task.done then
      table.insert(hl, "Done")
    else
      table.insert(hl, "Normal")
    end
  end

  if #state.tasks == 0 then
    table.insert(lines, " No tasks yet. Add with :SessionTodoAdd <text>")
    table.insert(hl, "Normal")
  end

  vim.api.nvim_buf_set_option(M.buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.buf, "modifiable", false)

  for i, h in ipairs(hl) do
    local name = "SessionTodo" .. h
    vim.cmd(string.format("syntax match %s /^%d:.*$/", name, i))
    local colors = {
      Title = { fg = "#50fa7b", bold = true },
      TimerRunning = { fg = "#ffb86c" },
      Selected = { fg = "#8be9fd", bold = true },
      Done = { fg = "#6272a4" },
      Normal = { fg = "#f8f8f2" },
    }
    if colors[h] then
      vim.api.nvim_buf_add_highlight(M.buf, -1, name, i - 1, 0, -1)
    end
  end
end

return M
