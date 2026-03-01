vim.cmd([[command! -nargs=* - SessionTodo callcomplete=file v:lua.require("session_todo").setup()]])
vim.cmd([[command! -nargs=? SessionTodoToggle call v:lua.require("session_todo").toggle()]])
vim.cmd([[command! -nargs=+ SessionTodoAdd call v:lua.require("session_todo").add_task(<q-args>)]])
vim.cmd([[command! SessionTodoStart call v:lua.require("session_todo").start_timer()]])
vim.cmd([[command! SessionTodoStop call v:lua.require("session_todo").stop_timer()]])

vim.keymap.set("n", "<leader>tt", require("session_todo").toggle, { desc = "Toggle SessionTodo" })
vim.keymap.set("n", "<leader>ts", function()
  local st = require("session_todo")
  if st.state.timer_running then
    st.stop_timer()
  else
    st.start_timer()
  end
end, { desc = "Start/Stop timer" })
