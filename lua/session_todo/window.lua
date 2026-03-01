local M = {}

M.win = nil
M.buf = nil
M.callbacks = {}
M.state = nil
M.config = nil
M.show_help = false
M.search_query = ""

local TASK_START_LINE = 3

function M.toggle(state, config, callbacks)
  M.callbacks = callbacks
  M.state = state
  M.config = config
  M.show_help = false
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
  local width = math.min(config.width or 50, vim.o.columns - 4)
  local height = math.min(config.height or 15, vim.o.lines - 4)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  M.buf = vim.api.nvim_create_buf(false, true)
  M.win = vim.api.nvim_open_win(M.buf, true, {
    relative = config.relative or "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  })

  vim.api.nvim_buf_set_option(M.buf, "filetype", "session_todo")
  vim.api.nvim_buf_set_option(M.buf, "modifiable", false)
  vim.api.nvim_win_set_option(M.win, "cursorline", true)

  local function map(key, fn)
    vim.keymap.set("n", key, fn, { buffer = M.buf, noremap = true, silent = true })
  end

  map("q", function()
    if M.show_help then
      M.show_help = false
      M.render(M.state, M.config)
      return
    end
    vim.api.nvim_win_close(M.win, true)
    M.win = nil
  end)

  map("g?", function()
    M.show_help = not M.show_help
    M.render(M.state, M.config)
  end)

  map("f", function()
    vim.cmd("stopinsert")
    vim.fn.inputsave()
    local query = vim.fn.input("Filter: ")
    vim.fn.inputrestore()
    M.search_query = query or ""
    M.render(M.state, M.config)
  end)

  map("j", function()
    if M.show_help then return end
    local filtered = M.get_filtered_tasks(M.state)
    local cursor = vim.api.nvim_win_get_cursor(M.win)
    local last_line = TASK_START_LINE + #filtered - 1
    if cursor[1] < last_line then
      vim.api.nvim_win_set_cursor(M.win, { cursor[1] + 1, 0 })
    end
  end)

  map("k", function()
    if M.show_help then return end
    local cursor = vim.api.nvim_win_get_cursor(M.win)
    if cursor[1] > TASK_START_LINE then
      vim.api.nvim_win_set_cursor(M.win, { cursor[1] - 1, 0 })
    end
  end)

  local function get_current_item_idx()
    local cursor = vim.api.nvim_win_get_cursor(M.win)
    local line = cursor[1]
    if line < TASK_START_LINE then return nil end
    local filtered = M.get_filtered_tasks(M.state)
    local item = filtered[line - TASK_START_LINE + 1]
    return item and item.original_idx or nil
  end

  map("<cr>", function()
    if M.show_help then
      M.show_help = false
      M.render(M.state, M.config)
      return
    end
    local idx = get_current_item_idx()
    if idx then M.callbacks.on_select(idx) end
  end)

  map(" ", function()
    local idx = get_current_item_idx()
    if idx then M.callbacks.on_toggle_task(idx) end
  end)

  map("a", function()
    M.add_task_interactive(M.callbacks.on_add_task)
  end)

  map("r", function()
    local idx = get_current_item_idx()
    if not idx then return end
    local task = M.state.tasks[idx]
    vim.fn.inputsave()
    local new_input = vim.fn.input("Rename: ", task.text)
    vim.fn.inputrestore()
    if new_input and new_input ~= "" then
      local text, duration = M.parse_task_input(new_input)
      M.callbacks.on_edit_task(idx, text, duration or task.duration)
    end
  end)

  map("e", function()
    local idx = get_current_item_idx()
    if not idx then return end
    local task = M.state.tasks[idx]
    vim.fn.inputsave()
    local dur_str = vim.fn.input("Duration (min): ", tostring(task.duration / 60))
    vim.fn.inputrestore()
    local dur = tonumber(dur_str)
    if dur and dur > 0 then
      M.callbacks.on_edit_duration(idx, dur * 60)
    end
  end)

  map("d", function()
    local idx = get_current_item_idx()
    if idx then M.callbacks.on_delete_task(idx) end
  end)

  map("<leader>s", function() M.callbacks.on_start_timer() end)
  map("<leader>r", function() M.callbacks.on_reset_timer() end)
  
  -- Initial cursor position
  vim.api.nvim_win_set_cursor(M.win, { TASK_START_LINE, 0 })
end

function M.get_filtered_tasks(state)
  local result = {}
  local query = M.search_query:lower()
  for i, task in ipairs(state.tasks) do
    if query == "" or task.text:lower():find(query, 1, true) then
      table.insert(result, { task = task, original_idx = i })
    end
  end
  return result
end

function M.parse_task_input(input)
  local text = input:gsub("%s+%d+[mh]?$", "")
  local dur_str = input:match("%s+(%d+[mh]?)$")
  local duration = nil
  if dur_str then
    local val = tonumber(dur_str:match("%d+"))
    if dur_str:find("h") then duration = val * 3600
    else duration = val * 60 end
  end
  return text, duration
end

function M.render(state, config)
  if not M.win or not vim.api.nvim_win_is_valid(M.win) then return end
  
  local lines = {}
  if M.show_help then
    lines = { " Help ", "", " j/k navigate", " Enter select", " Space toggle", " a add", " r rename", " e duration", " d delete", " f filter", " <leader>r reset", " <leader>s start/stop", " g? help", " q close" }
  else
    local session = state.session_type:gsub("^%l", string.upper)
    local timer_str = "--:--"
    if state.timer_running and state.tasks[state.current_task_idx] then
      local t = state.tasks[state.current_task_idx]
      local rem = t.duration - t.elapsed
      timer_str = string.format("%02d:%02d", math.floor(rem / 60), rem % 60)
    end
    table.insert(lines, string.format(" %s | %s | %s", session, timer_str, M.search_query ~= "" and "/"..M.search_query or ""))
    table.insert(lines, "")
    local filtered = M.get_filtered_tasks(state)
    for _, item in ipairs(filtered) do
      local t = item.task
      local status = t.done and "[x]" or "[ ]"
      local prefix = item.original_idx == state.current_task_idx and ">" or " "
      table.insert(lines, string.format("%s %s %s %s (%d/%dm)", prefix, t.emoji or "📌", status, t.text, math.floor(t.elapsed/60), math.floor(t.duration/60)))
    end
    if #filtered == 0 then table.insert(lines, " (empty)") end
  end

  local cursor = vim.api.nvim_win_get_cursor(M.win)
  vim.api.nvim_buf_set_option(M.buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.buf, "modifiable", false)
  
  -- Preserve/adjust cursor
  local max_line = #lines
  local new_line = math.min(cursor[1], max_line)
  if new_line > 0 then
    vim.api.nvim_win_set_cursor(M.win, { new_line, 0 })
  end

  vim.api.nvim_buf_clear_namespace(M.buf, -1, 0, -1)
  vim.api.nvim_buf_add_highlight(M.buf, 0, "Title", 0, 0, -1)
end

function M.pick(state, config, callbacks)
  local items = {}
  for i, t in ipairs(state.tasks) do
    table.insert(items, { idx = i, text = t.text, display = string.format("%s %s", t.done and "[x]" or "[ ]", t.text) })
  end
  vim.ui.select(items, { prompt = "Select task:", format_item = function(item) return item.display end }, function(choice)
    if choice then callbacks.on_select(choice.idx) end
  end)
end

function M.add_task_interactive(callback)
  vim.fn.inputsave()
  local input = vim.fn.input("New task: ")
  vim.fn.inputrestore()
  if input and input ~= "" then
    local text, duration = M.parse_task_input(input)
    callback(text, duration)
  end
end

return M
