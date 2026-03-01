local M = {}
local storage = require("session_todo.storage")
local window = require("session_todo.window")
local timer = require("session_todo.timer")
local vim = vim

M.state = {
  tasks = {},
  current_task_idx = 0,
  timer_running = false,
  session_type = "work",
}

M.config = {
  work_duration = 25 * 60,
  short_break = 5 * 60,
  long_break = 15 * 60,
  storage_path = vim.fn.stdpath("data") .. "/session_todos.json",
  relative = "editor",
  width = 45,
  height = 12,
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  M.state.tasks = storage.load(M.config.storage_path)
  timer.set_notify_handler(function(msg, level)
    vim.notify(msg, level, { title = "SessionTodo" })
  end)
end

function M.toggle()
  window.toggle(M.state, M.config, {
    on_select = function(idx)
      M.select_task(idx)
    end,
    on_toggle_task = function(idx)
      M.toggle_task(idx)
    end,
    on_add_task = function(text, duration)
      M.add_task(text, duration)
    end,
    on_delete_task = function(idx)
      M.delete_task(idx)
    end,
    on_edit_task = function(idx, text, duration)
      M.edit_task(idx, text, duration)
    end,
    on_edit_duration = function(idx, duration)
      M.edit_duration(idx, duration)
    end,
    on_start_timer = function()
      M.start_timer()
    end,
    on_stop_timer = function()
      M.stop_timer()
    end,
    on_reset_timer = function()
      M.reset_timer()
    end,
  })
end

function M.pick()
  window.pick(M.state, M.config, {
    on_select = function(idx)
      M.select_task(idx)
    end,
  })
end

function M.add_task_interactive()
  window.add_task_interactive(function(text, duration)
    M.add_task(text, duration)
  end)
end

function M.select_task(idx)
  M.state.current_task_idx = idx
  window.render(M.state, M.config)
end

function M.toggle_task(idx)
  M.state.tasks[idx].done = not M.state.tasks[idx].done
  storage.save(M.config.storage_path, M.state.tasks)
  window.render(M.state, M.config)
end

function M.add_task(text, duration)
  table.insert(M.state.tasks, {
    text = text,
    duration = duration or M.config.work_duration,
    done = false,
    elapsed = 0,
  })
  storage.save(M.config.storage_path, M.state.tasks)
  window.render(M.state, M.config)
end

function M.delete_task(idx)
  table.remove(M.state.tasks, idx)
  if M.state.current_task_idx == idx then
    M.state.current_task_idx = 0
  elseif M.state.current_task_idx > idx then
    M.state.current_task_idx = M.state.current_task_idx - 1
  end
  storage.save(M.config.storage_path, M.state.tasks)
  window.render(M.state, M.config)
end

function M.edit_task(idx, text, duration)
  if idx > 0 and idx <= #M.state.tasks then
    M.state.tasks[idx].text = text
    if duration then
      M.state.tasks[idx].duration = duration
    end
    storage.save(M.config.storage_path, M.state.tasks)
    window.render(M.state, M.config)
  end
end

function M.edit_duration(idx, duration)
  if idx > 0 and idx <= #M.state.tasks then
    M.state.tasks[idx].duration = duration
    storage.save(M.config.storage_path, M.state.tasks)
    window.render(M.state, M.config)
  end
end

function M.start_timer()
  if M.state.current_task_idx == 0 or M.state.current_task_idx > #M.state.tasks then
    vim.notify("No task selected", vim.log.levels.WARN, { title = "SessionTodo" })
    return
  end

  local task = M.state.tasks[M.state.current_task_idx]
  local task_idx = M.state.current_task_idx
  M.state.timer_running = true

  timer.start(task.duration, function()
    M.on_timer_complete()
  end, function(remaining)
    M.state.tasks[task_idx].elapsed = M.state.tasks[task_idx].duration - remaining
    window.render(M.state, M.config)
  end)
  window.render(M.state, M.config)
end

function M.stop_timer()
  timer.stop()
  M.state.timer_running = false
  storage.save(M.config.storage_path, M.state.tasks)
  window.render(M.state, M.config)
end

function M.reset_timer()
  if M.state.current_task_idx > 0 and M.state.current_task_idx <= #M.state.tasks then
    M.state.tasks[M.state.current_task_idx].elapsed = 0
    storage.save(M.config.storage_path, M.state.tasks)
    window.render(M.state, M.config)
  end
end

function M.on_timer_complete()
  M.state.timer_running = false
  local session = M.state.session_type
  if session == "work" then
    M.state.session_type = "break"
    vim.notify("Work session complete! Time for break.", vim.log.levels.INFO, { title = "SessionTodo" })
  else
    M.state.session_type = "work"
    vim.notify("Break over! Ready to work.", vim.log.levels.INFO, { title = "SessionTodo" })
  end
  storage.save(M.config.storage_path, M.state.tasks)
  window.render(M.state, M.config)
end

function M.get_statusline()
  if not M.state.timer_running then
    return ""
  end
  local task = M.state.tasks[M.state.current_task_idx]
  if not task then return "" end
  local remaining = task.duration - task.elapsed
  local mins = math.floor(remaining / 60)
  local secs = remaining % 60
  return string.format("⏱ %02d:%02d [%s]", mins, secs, task.text)
end

return M
