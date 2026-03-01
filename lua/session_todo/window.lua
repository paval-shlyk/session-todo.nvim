local M = {}

M.win = nil
M.buf = nil
M.callbacks = {}
M.state = nil
M.config = nil

local TASK_START_LINE = 4

function M.toggle(state, config, callbacks)
  M.callbacks = callbacks
  M.state = state
  M.config = config
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    vim.api.nvim_win_close(M.win, true)
    M.win = nil
    return
  end
  M.create_window(state, config)
  M.render(state, config)
end

function M.create_window(state, config)
  local width = math.min(50, vim.o.columns - 4)
  local height = math.min(15, vim.o.lines - 4)
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
  end, { buffer = M.buf, noremap = true, silent = true })

  vim.keymap.set("n", "j", function()
    local cursor = vim.api.nvim_win_get_cursor(M.win)
    local new_line = math.min(cursor[1] + 1, #M.state.tasks + TASK_START_LINE - 1)
    vim.api.nvim_win_set_cursor(M.win, { new_line, 0 })
  end, { buffer = M.buf, noremap = true, silent = true })

  vim.keymap.set("n", "k", function()
    local cursor = vim.api.nvim_win_get_cursor(M.win)
    local new_line = math.max(cursor[1] - 1, TASK_START_LINE)
    vim.api.nvim_win_set_cursor(M.win, { new_line, 0 })
  end, { buffer = M.buf, noremap = true, silent = true })

  vim.keymap.set("n", "<cr>", function()
    local cursor = vim.api.nvim_win_get_cursor(M.win)
    local line = cursor[1]
    if line >= TASK_START_LINE and line <= TASK_START_LINE + #M.state.tasks - 1 then
      M.callbacks.on_select(line - TASK_START_LINE + 1)
    end
  end, { buffer = M.buf, noremap = true, silent = true })

  vim.keymap.set("n", " ", function()
    local cursor = vim.api.nvim_win_get_cursor(M.win)
    local line = cursor[1]
    if line >= TASK_START_LINE and line <= TASK_START_LINE + #M.state.tasks - 1 then
      M.callbacks.on_toggle_task(line - TASK_START_LINE + 1)
    end
  end, { buffer = M.buf, noremap = true, silent = true })

  vim.keymap.set("n", "a", function()
    vim.cmd("stopinsert")
    vim.cmd([[call inputsave()]])
    vim.cmd([[let g:session_todo_new_task = input('New task: ')]])
    vim.cmd([[call inputrestore()]])
    local new_task = vim.g.session_todo_new_task
    vim.g.session_todo_new_task = nil
    if new_task and new_task ~= "" then
      M.callbacks.on_add_task(new_task)
    end
  end, { buffer = M.buf, noremap = true, silent = true })

  vim.keymap.set("n", "d", function()
    local cursor = vim.api.nvim_win_get_cursor(M.win)
    local line = cursor[1]
    if line >= TASK_START_LINE and line <= TASK_START_LINE + #M.state.tasks - 1 then
      M.callbacks.on_delete_task(line - TASK_START_LINE + 1)
    end
  end, { buffer = M.buf, noremap = true, silent = true })

  vim.keymap.set("n", "<leader>s", function()
    if M.state.timer_running then
      M.callbacks.on_stop_timer()
    else
      M.callbacks.on_start_timer()
    end
  end, { buffer = M.buf, noremap = true, silent = true })
end

function M.render(state, config)
  if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
    return
  end

  local lines = {}

  local session_indicator = state.session_type == "work" and "Work" or "Break"
  table.insert(lines, " ▶ " .. session_indicator .. " ")

  if state.timer_running then
    local task = state.tasks[state.current_task_idx]
    if task then
      local remaining = task.duration - task.elapsed
      local mins = math.floor(remaining / 60)
      local secs = remaining % 60
      table.insert(lines, string.format(" ⏱ %02d:%02d ", mins, secs) .. task.text)
    else
      table.insert(lines, " No task selected ")
    end
  else
    table.insert(lines, " ⏱ --:-- ")
  end

  table.insert(lines, "─────────────────")

  for i, task in ipairs(state.tasks) do
    local status = task.done and "✓" or "○"
    local prefix = i == state.current_task_idx and "▶" or " "
    local elapsed = math.floor(task.elapsed / 60)
    local dur = math.floor(task.duration / 60)
    table.insert(lines, string.format("%s %s %s %d/%dm", prefix, status, task.text, elapsed, dur))
  end

  if #state.tasks == 0 then
    table.insert(lines, " (empty) ")
  end

  vim.api.nvim_buf_set_option(M.buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.buf, "modifiable", false)

  vim.api.nvim_buf_clear_namespace(M.buf, -1, 0, -1)
  vim.api.nvim_buf_add_highlight(M.buf, 0, "String", 0, 0, -1)
  vim.api.nvim_buf_add_highlight(M.buf, 0, "Number", 1, 0, -1)

  local task_start = TASK_START_LINE - 1
  for i = 1, #state.tasks do
    local line_idx = task_start + i - 1
    if i == state.current_task_idx then
      vim.api.nvim_buf_add_highlight(M.buf, 0, "Keyword", line_idx, 0, 2)
    elseif state.tasks[i].done then
      vim.api.nvim_buf_add_highlight(M.buf, 0, "Comment", line_idx, 0, 2)
    end
  end
end

return M
