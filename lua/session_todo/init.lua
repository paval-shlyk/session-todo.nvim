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

local EMOJIS = { "📌", "📝", "💡", "🔧", "🚀", "⚡", "🎯", "📋", "✅", "🔍", "💻", "🛠", "📦", "🎨", "🔨" }

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  M.state.tasks = storage.load(M.config.storage_path)
  timer.set_notify_handler(function(msg, level)
    vim.notify(msg, level, { title = "SessionTodo" })
  end)
end

function M.toggle()
  window.toggle(M.state, M.config, {
    on_select = M.select_task,
    on_toggle_task = M.toggle_task,
    on_add_task = M.add_task,
    on_delete_task = M.delete_task,
    on_edit_task = M.edit_task,
    on_edit_duration = M.edit_duration,
    on_start_timer = M.start_timer,
    on_stop_timer = M.stop_timer,
    on_reset_timer = M.reset_timer,
  })
end

function M.pick()
  window.pick(M.state, M.config, {
    on_select = M.select_task,
  })
end

function M.add_task_interactive()
  window.add_task_interactive(M.add_task)
end

function M.select_task(idx)
  M.state.current_task_idx = idx
  window.render(M.state, M.config)
end

function M.toggle_task(idx)
  if M.state.tasks[idx] then
    M.state.tasks[idx].done = not M.state.tasks[idx].done
    storage.save(M.config.storage_path, M.state.tasks)
    window.render(M.state, M.config)
  end
end

function M.add_task(text, duration)
  local emoji = EMOJIS[math.random(#EMOJIS)]
  table.insert(M.state.tasks, {
    text = text,
    duration = duration or M.config.work_duration,
    done = false,
    elapsed = 0,
    emoji = emoji,
  })
  storage.save(M.config.storage_path, M.state.tasks)
  window.render(M.state, M.config)
end

function M.delete_task(idx)
  if M.state.tasks[idx] then
    table.remove(M.state.tasks, idx)
    if M.state.current_task_idx == idx then
      M.state.current_task_idx = 0
    elseif M.state.current_task_idx > idx then
      M.state.current_task_idx = M.state.current_task_idx - 1
    end
    storage.save(M.config.storage_path, M.state.tasks)
    window.render(M.state, M.config)
  end
end

function M.edit_task(idx, text, duration)
  if M.state.tasks[idx] then
    M.state.tasks[idx].text = text
    if duration then
      M.state.tasks[idx].duration = duration
    end
    storage.save(M.config.storage_path, M.state.tasks)
    window.render(M.state, M.config)
  end
end

function M.edit_duration(idx, duration)
  if M.state.tasks[idx] then
    M.state.tasks[idx].duration = duration
    storage.save(M.config.storage_path, M.state.tasks)
    window.render(M.state, M.config)
  end
end

function M.start_timer()
  if M.state.timer_running then
    M.stop_timer()
    return
  end

  if M.state.current_task_idx == 0 or not M.state.tasks[M.state.current_task_idx] then
    vim.notify("No task selected", vim.log.levels.WARN, { title = "SessionTodo" })
    return
  end

  local task_idx = M.state.current_task_idx
  local task = M.state.tasks[task_idx]
  local remaining = task.duration - task.elapsed

  if remaining <= 0 then
    vim.notify("Task already finished", vim.log.levels.INFO, { title = "SessionTodo" })
    return
  end

  M.state.timer_running = true
  timer.start(remaining, function()
    M.on_timer_complete()
  end, function(new_remaining)
    if M.state.tasks[task_idx] then
      M.state.tasks[task_idx].elapsed = M.state.tasks[task_idx].duration - new_remaining
      window.render(M.state, M.config)
    end
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
  local idx = M.state.current_task_idx
  if idx > 0 and M.state.tasks[idx] then
    M.state.tasks[idx].elapsed = 0
    if M.state.timer_running then
      M.stop_timer()
    end
    storage.save(M.config.storage_path, M.state.tasks)
    window.render(M.state, M.config)
  end
end

function M.on_timer_complete()
  M.state.timer_running = false
  if M.state.session_type == "work" then
    M.state.session_type = "break"
    vim.notify("Session complete! Break time.", vim.log.levels.INFO, { title = "SessionTodo" })
  else
    M.state.session_type = "work"
    vim.notify("Break over! Back to work.", vim.log.levels.INFO, { title = "SessionTodo" })
  end
  storage.save(M.config.storage_path, M.state.tasks)
  window.render(M.state, M.config)
end

function M.get_statusline()
  if not M.state.timer_running then return "" end
  local task = M.state.tasks[M.state.current_task_idx]
  if not task then return "" end
  local rem = task.duration - task.elapsed
  return string.format("⏱ %02d:%02d [%s]", math.floor(rem / 60), rem % 60, task.text)
end

return M
