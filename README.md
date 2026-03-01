# SessionTodo.nvim

A minimal floating todo plugin for NeoVIM with integrated timer for tracking work sessions.

## Purpose

Manage tasks per working session with time estimation and Pomodoro-style timer tracking.

## Installation

Using packer:
```lua
use "~/path/to/session_todo.nvim"
```

Using lazy.nvim:
```lua
{ "~/path/to/session_todo.nvim" }
```

## Setup

```lua
require("session_todo").setup({
  work_duration = 25 * 60,    -- 25 minutes
  short_break = 5 * 60,       -- 5 minutes
  long_break = 15 * 60,       -- 15 minutes
})
```

## Usage

| Command | Description |
|---------|-------------|
| `:SessionTodoToggle` | Toggle floating window |
| `:SessionTodoAdd <text> [duration]` | Add task (duration: 25, 25m, 1h) |
| `:SessionTodoPick` | Quick pick task |
| `:SessionTodoStart` | Start timer |
| `:SessionTodoStop` | Stop timer |

### Widget Keymaps

| Key | Description |
|-----|-------------|
| `j/k` | Navigate tasks |
| `Enter` | Select task |
| `Space` | Toggle complete |
| `a` | Add task |
| `r` | Rename task (with optional duration) |
| `e` | Edit duration (minutes) |
| `d` | Delete task |
| `f` | Filter/search tasks |
| `g?` | Help |
| `q` | Close |

### Timer

- Select a task with `Enter`
- Press `<leader>s` to start/stop timer
- Timer shows in widget header and in lualine (if integrated)

### Global Keymaps

| Key | Description |
|-----|-------------|
| `<leader>tt` | Toggle window |
| `<leader>tp` | Pick task |
| `<leader>ts` | Start/Stop timer |

## Lualine Integration

```lua
-- In your lualine config
require("lualine").setup({
  sections = {
    lualine_c = {
      { require("session_todo").get_statusline, color = { fg = "#50fa7b" } }
    }
  }
})
```

## Features

- Floating task list with timer display
- Search/filter tasks by name
- Editable task duration
- Session tracking (Work/Break cycles)
- Tasks saved to JSON (`~/.local/share/nvim/session_todos.json`)
- Notifications on timer complete
