local M = {}
local vim = vim

M.timer = nil
M.notify_handler = nil
M.current_task_idx = 0

function M.set_notify_handler(handler)
  M.notify_handler = handler
end

function M.set_task_idx(idx)
  M.current_task_idx = idx
end

function M.start(duration, on_complete, on_tick)
  M.stop()
  local remaining = duration
  local task_idx = M.current_task_idx

  M.timer = vim.fn.timer_start(1000, function()
    remaining = remaining - 1
    if on_tick then
      on_tick(remaining, task_idx)
    end
    if remaining <= 0 then
      M.stop()
      if on_complete then
        on_complete()
      end
    end
  end, { ["repeat"] = true })
end

function M.stop()
  if M.timer then
    vim.fn.timer_stop(M.timer)
    M.timer = nil
  end
end

return M
