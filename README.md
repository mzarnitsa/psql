# Neovim/nvim psql plugin

This is a simple plugin to execute sql query from inside nvim editor.

The plugin executes query with postgres `psql` command, opens a new buffer in nvim and pastes the results there

`picture`

Default shorcuts:
  [normal mode] <leader>-e - execute line under cursor
  [visual mode] <leader>-e - execute selection
  [normal mode] <leader>-r - execute current paragraph

  <leader>-w - close last result buffer
  <leader>-W - close all result buffers

# Installation

# Configuration

Minimal. Include the following into `~/.config/nvim/init.lua` file

```
require('psql').setup({
  database_name = 'postgres'
})
```

All configuration parameters

```
require('psql').setup({
  database_name       = 'postgres'
  execute_line        = '<leader>e',
  execute_selection   = '<leader>e',
  execute_paragraph   = '<leader>r',

  close_latest_result = '<leader>w',
  close_all_results   = '<leader>W',
})
```
