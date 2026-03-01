local M = {}

function M.load(path)
  local f = io.open(path, "r")
  if not f then
    return {}
  end
  local content = f:read("*a")
  f:close()
  if content == "" then
    return {}
  end
  local ok, data = pcall(vim.json.decode, content)
  if not ok then
    return {}
  end
  return data
end

function M.save(path, tasks)
  local f = io.open(path, "w")
  if not f then
    return
  end
  f:write(vim.json.encode(tasks))
  f:close()
end

return M
