local M = {}

M.win = nil
M.buf = nil
M.callbacks = {}
M.state = nil
M.config = nil
M.show_help = false
M.search_mode = false
M.search_query = ""

local TASK_START_LINE = 4

function M.toggle(state, config, callbacks)
  M.callbacks = callbacks
  M.state = state
  M.config = config
  M.show_help = false
  M.search_mode = false
  M.search_query = ""
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

  local relative_to = config.relative or "editor"

  M.buf = vim.api.nvim_create_buf(false, true)
  M.win = vim.api.nvim_open_win(M.buf, true, {
    relative = relative_to,
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
    if M.show_help or M.search_mode then
      M.show_help = false
      M.search_mode = false
      M.search_query = ""
      M.render(M.state, M.config)
      return
    end
    if M.win and vim.api.nvim_win_is_valid(M.win) then
      vim.api.nvim_win_close(M.win, true)
      M.win = nil
    end
  end, { buffer = M.buf, noremap = true, silent = true })

  vim.keymap.set("n", "g?", function()
    M.show_help = not M.show_help
    M.search_mode = false
    M.render(M.state, M.config)
  end, { buffer = M.buf, noremap = true, silent = true })

  vim.keymap.set("n", "f", function()
    M.search_mode = true
    M.show_help = false
    vim.defer_fn(function()
      vim.cmd([[call inputsave()]])
      vim.cmd([[let g:session_todo_search = input('Filter: ')]])
      vim.cmd([[call inputrestore()]])
      local query = vim.g.session_todo_search or ""
      vim.g.session_todo_search = nil
      M.search_query = query
      M.render(M.state, M.config)
    end, 10)
  end, { buffer = M.buf, noremap = true, silent = true })

  vim.keymap.set("n", "j", function()
    if M.show_help or M.search_mode then return end
    local filtered = M.get_filtered_tasks(M.state)
    if #filtered == 0 then return end
    local cursor = vim.api.nvim_win_get_cursor(M.win)
    local max_line = math.min(#filtered + TASK_START_LINE - 1, 3 + #filtered)
    local new_line = math.min(cursor[1] + 1, max_line)
    vim.api.nvim_win_set_cursor(M.win, { new_line, 0 })
  end, { buffer = M.buf, noremap = true, silent = true })

  vim.keymap.set("n", "k", function()
    if M.show_help or M.search_mode then return end
    local cursor = vim.api.nvim_win_get_cursor(M.win)
    local new_line = math.max(cursor[1] - 1, TASK_START_LINE)
    vim.api.nvim_win_set_cursor(M.win, { new_line, 0 })
  end, { buffer = M.buf, noremap = true, silent = true })

  vim.keymap.set("n", "<cr>", function()
    if M.show_help or M.search_mode then
      M.show_help = false
      M.search_mode = false
      M.render(M.state, M.config)
      return
    end
    local cursor = vim.api.nvim_win_get_cursor(M.win)
    local line = cursor[1]
    local filtered = M.get_filtered_tasks(M.state)
    if line >= TASK_START_LINE and line <= TASK_START_LINE + #filtered - 1 then
      local original_idx = filtered[line - TASK_START_LINE + 1].original_idx
      M.callbacks.on_select(original_idx)
    end
  end, { buffer = M.buf, noremap = true, silent = true })

  vim.keymap.set("n", " ", function()
    if M.show_help or M.search_mode then return end
    local cursor = vim.api.nvim_win_get_cursor(M.win)
    local line = cursor[1]
    local filtered = M.get_filtered_tasks(M.state)
    if line >= TASK_START_LINE and line <= TASK_START_LINE + #filtered - 1 then
      local original_idx = filtered[line - TASK_START_LINE + 1].original_idx
      M.callbacks.on_toggle_task(original_idx)
    end
  end, { buffer = M.buf, noremap = true, silent = true })

  vim.keymap.set("n", "a", function()
    if M.show_help or M.search_mode then return end
    vim.defer_fn(function()
      vim.cmd([[call inputsave()]])
      vim.cmd([[let g:session_todo_new_task = input('Task [duration]: ')]])
      vim.cmd([[call inputrestore()]])
      local input = vim.g.session_todo_new_task
      vim.g.session_todo_new_task = nil
      if input and input ~= "" then
        local text, duration = M.parse_task_input(input)
        if text and text ~= "" then
          M.callbacks.on_add_task(text, duration)
        end
      end
    end, 10)
  end, { buffer = M.buf, noremap = true, silent = true })

  vim.keymap.set("n", "r", function()
    if M.show_help or M.search_mode then return end
    local cursor = vim.api.nvim_win_get_cursor(M.win)
    local line = cursor[1]
    local filtered = M.get_filtered_tasks(M.state)
    if line >= TASK_START_LINE and line <= TASK_START_LINE + #filtered - 1 then
      local original_idx = filtered[line - TASK_START_LINE + 1].original_idx
      local task = M.state.tasks[original_idx]
      vim.defer_fn(function()
        vim.cmd([[call inputsave()]])
        vim.cmd([[let g:session_todo_edit = input('Edit task: ', ']] .. task.text .. [[')]])
        vim.cmd([[call inputrestore()]])
        local new_text = vim.g.session_todo_edit
        vim.g.session_todo_edit = nil
        if new_text and new_text ~= "" then
          local text, duration = M.parse_task_input(new_text)
          if text and text ~= "" then
            M.callbacks.on_edit_task(original_idx, text, duration or task.duration)
          end
        end
      end, 10)
    end
  end, { buffer = M.buf, noremap = true, silent = true })

  vim.keymap.set("n", "e", function()
    if M.show_help or M.search_mode then return end
    local cursor = vim.api.nvim_win_get_cursor(M.win)
    local line = cursor[1]
    local filtered = M.get_filtered_tasks(M.state)
    if line >= TASK_START_LINE and line <= TASK_START_LINE + #filtered - 1 then
      local original_idx = filtered[line - TASK_START_LINE + 1].original_idx
      local task = M.state.tasks[original_idx]
      vim.defer_fn(function()
        vim.cmd([[call inputsave()]])
        vim.cmd([[let g:session_todo_duration = input('Duration (min): ', ']] .. (task.duration / 60) .. [[')]])
        vim.cmd([[call inputrestore()]])
        local duration_str = vim.g.session_todo_duration
        vim.g.session_todo_duration = nil
        local duration = tonumber(duration_str)
        if duration and duration > 0 and duration <= 480 then
          M.callbacks.on_edit_duration(original_idx, duration * 60)
        end
      end, 10)
    end
  end, { buffer = M.buf, noremap = true, silent = true })

  vim.keymap.set("n", "d", function()
    if M.show_help or M.search_mode then return end
    local cursor = vim.api.nvim_win_get_cursor(M.win)
    local line = cursor[1]
    local filtered = M.get_filtered_tasks(M.state)
    if line >= TASK_START_LINE and line <= TASK_START_LINE + #filtered - 1 then
      local original_idx = filtered[line - TASK_START_LINE + 1].original_idx
      M.callbacks.on_delete_task(original_idx)
    end
  end, { buffer = M.buf, noremap = true, silent = true })

  vim.keymap.set("n", "<leader>s", function()
    if M.show_help or M.search_mode then return end
    if M.state.timer_running then
      M.callbacks.on_stop_timer()
    else
      M.callbacks.on_start_timer()
    end
  end, { buffer = M.buf, noremap = true, silent = true })
end

function M.get_filtered_tasks(state)
  if M.search_query == "" then
    local result = {}
    for i, task in ipairs(state.tasks) do
      table.insert(result, { task = task, original_idx = i })
    end
    return result
  end
  local query = M.search_query:lower()
  local result = {}
  for i, task in ipairs(state.tasks) do
    if task.text:lower():find(query, 1, true) then
      table.insert(result, { task = task, original_idx = i })
    end
  end
  return result
end

function M.parse_task_input(input)
  local duration
  local text = input
  
  local dur_min = input:match("(%d+)m$")
  local dur_hr = input:match("(%d+)h$")
  local dur_num = input:match("(%d+)$")
  
  if dur_min then
    duration = tonumber(dur_min) * 60
    text = input:sub(1, -(#dur_min + 2))
  elseif dur_hr then
    duration = tonumber(dur_hr) * 3600
    text = input:sub(1, -(#dur_hr + 2))
  elseif dur_num then
    duration = tonumber(dur_num) * 60
    text = input:sub(1, -(#dur_num + 1))
  end
  
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  return text, duration
end

function M.render(state, config)
  if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
    return
  end

  if M.show_help then
    M.render_help()
    return
  end

  local lines = {}
  local filtered = M.get_filtered_tasks(state)

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
    table.insert(lines, " ⏱ --:--  <leader>s to start")
  end

  if M.search_query ~= "" then
    table.insert(lines, " /" .. M.search_query .. " ")
  else
    table.insert(lines, "─────────────────")
  end

  for i, item in ipairs(filtered) do
    local task = item.task
    local status = task.done and "✓" or "○"
    local prefix = item.original_idx == state.current_task_idx and "▶" or " "
    local elapsed = math.floor(task.elapsed / 60)
    local dur = math.floor(task.duration / 60)
    table.insert(lines, string.format("%s %s %s %d/%dm", prefix, status, task.text, elapsed, dur))
  end

  if #filtered == 0 then
    if M.search_query ~= "" then
      table.insert(lines, " (no matches) ")
    else
      table.insert(lines, " (empty - a to add) ")
    end
  end

  vim.api.nvim_buf_set_option(M.buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.buf, "modifiable", false)

  vim.api.nvim_buf_clear_namespace(M.buf, -1, 0, -1)
  vim.api.nvim_buf_add_highlight(M.buf, 0, "String", 0, 0, -1)
  vim.api.nvim_buf_add_highlight(M.buf, 0, "Number", 1, 0, -1)

  if M.search_query ~= "" then
    vim.api.nvim_buf_add_highlight(M.buf, 0, "Number", 2, 0, -1)
  end

  local task_start = TASK_START_LINE - 1
  for i, item in ipairs(filtered) do
    local line_idx = task_start + i - 1
    if item.original_idx == state.current_task_idx then
      vim.api.nvim_buf_add_highlight(M.buf, 0, "Keyword", line_idx, 0, 2)
    elseif item.task.done then
      vim.api.nvim_buf_add_highlight(M.buf, 0, "Comment", line_idx, 0, 2)
    end
  end
end

function M.render_help()
  local lines = {
    " SessionTodo Help ",
    "─────────────────",
    " j/k   move up/down",
    " Enter select task",
    " a     add task",
    " r     rename task",
    " e     edit duration",
    " d     delete task",
    " Space toggle done",
    " f     filter/search",
    " g?    toggle help",
    " q     close",
  }

  vim.api.nvim_buf_set_option(M.buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.buf, "modifiable", false)

  vim.api.nvim_buf_clear_namespace(M.buf, -1, 0, -1)
  vim.api.nvim_buf_add_highlight(M.buf, 0, "String", 0, 0, -1)
end

function M.pick(state, config, callbacks)
  vim.ui.select(state.tasks, {
    prompt = "Select task:",
    format_item = function(item)
      return (item.done and "[x] " or "[ ] ") .. item.text
    end,
  }, function(selected)
    if selected then
      for i, task in ipairs(state.tasks) do
        if task == selected then
          callbacks.on_select(i)
          break
        end
      end
    end
  end)
end

return M
