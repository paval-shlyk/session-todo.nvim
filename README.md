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
| `:SessionTodoAdd <text>` | Add new task |
| `:SessionTodoStart` | Start timer |
| `:SessionTodoStop` | Stop timer |

### Keymaps

| Key | Description |
|-----|-------------|
| `<leader>tt` | Toggle window |
| `<leader>ts` | Start/Stop timer |
| `Enter` | Select task |
| `Space` | Toggle task complete |
| `q` | Close window |

## Features

- Floating task list with timer display
- Session tracking (Work/Break cycles)
- Tasks saved to JSON (`~/.local/share/nvim/session_todos.json`)
- Notifications on timer complete
