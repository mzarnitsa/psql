local PSQL = {
  config = {
    -- postgresql database name
    -- dev environment is assumed for this plugin
    -- thus no user name, password is provided here to make it simple
    database_name       = '',

    -- shortcut to execute query under the cursor line
    execute_line        = '<leader>e',
    -- shortcut to execute query in selected text
    execute_selection   = '<leader>e',
    -- shortcut to execute query in current paragraph
    execute_paragraph   = '<leader>r',

    -- shortcut to close latest result bufer
    close_latest_result = '<leader>w',
    -- shortcut to close all result buffers
    close_all_results   = '<leader>W',
  },
}

local query_result_buffers = {}

local function run_query(query)
  -- strip leading and trailing spaces
  query = string.gsub(query, '^%s*(.-)%s*$', '%1')

  if (query == nil or query == '') then
    print('psql plugin: query is empty')
    return
  end

  -- open horizontally split new window
  vim.cmd('split')
  win = vim.api.nvim_get_current_win()
  buf = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_win_set_buf(win, buf)

  -- remember new buffer for later to be able to close it
  table.insert(query_result_buffers, buf)

  -- show "Running ..." text until query is finished executing
  vim.api.nvim_buf_set_lines(buf, 0, -1, true, {'# Running...', query, ''})
  vim.cmd('redraw')

  -- save query to a temp file
  tmp_file = os.tmpname()
  f = io.open(tmp_file, 'w+')
  io.output(f)
  io.write(query)
  io.close(f)

  -- execute query
  local result = vim.fn.systemlist("psql " .. PSQL.config.database_name .. ' -f ' .. tmp_file)
  os.remove(tmp_file)

  -- replace result buffer with query results
  vim.api.nvim_buf_set_lines(buf, 0, -1, true, {query, ''})
  vim.api.nvim_buf_set_lines(buf, -1, -1, true, result)
end

function PSQL.query_current_line()
  line_number = vim.api.nvim_win_get_cursor(0)[1]
  query = vim.api.nvim_buf_get_lines(0, line_number - 1, line_number, false)

  query = query[1]
  return run_query(query)
end

function PSQL.query_selection()
  selection_start = vim.api.nvim_buf_get_mark(0, "<")
  selection_end = vim.api.nvim_buf_get_mark(0, ">")

  line1 = selection_start[1]
  col1 = selection_start[2]
  line2 = selection_end[1]
  col2 = selection_end[2] + 1

  lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
  query = ''

  if line2 == line1 then
    query = string.sub(lines[1], col1+1, col2)
  else
    query = string.sub(lines[1], col1+1)

    last_line_index = line2-line1+1

    for i = 2, last_line_index-1, 1 do
      query = query .. ' ' .. lines[i]
    end

    last_line = lines[last_line_index]
    query = query .. ' ' .. string.sub(last_line, 0, col2)
  end

  return run_query(query)
end

function PSQL.query_paragraph()
  line1 = vim.api.nvim_buf_get_mark(0, "(")[1]
  line2 = vim.api.nvim_buf_get_mark(0, ")")[1]

  lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
  query = ''
  for _,v in pairs(lines) do
    query = query .. ' ' .. v
  end

  return run_query(query)
end

function PSQL.close_latest_result()
  buf = table.remove(query_result_buffers)
  if buf == nil then return end

  vim.cmd('bd ' .. buf)
end

function PSQL.close_all_results()
  while table.getn(query_result_buffers) > 0 do
    buf = table.remove(query_result_buffers)

    vim.cmd('bd ' .. buf)
  end
end

function PSQL.setup(config)
  PSQL.config = vim.tbl_extend('force', PSQL.config, config or {})

  if PSQL.config.database_name == '' then
    error('psql plugin: database_name was not provided')
  end

  map_opts = {noremap = true, silent = true, nowait = true}
  vim.api.nvim_set_keymap('n', PSQL.config.execute_paragraph, ":lua require('psql').query_paragraph()<CR>", map_opts)
  vim.api.nvim_set_keymap('n', PSQL.config.execute_line, ":lua require('psql').query_current_line()<CR>", map_opts)
  vim.api.nvim_set_keymap('v', PSQL.config.execute_selection, ":lua require('psql').query_selection()<CR>", map_opts)

  vim.api.nvim_set_keymap('n', PSQL.config.close_latest_result, ":lua require('psql').close_latest_result()<CR>", map_opts)
  vim.api.nvim_set_keymap('n', PSQL.config.close_all_results, ":lua require('psql').close_all_results()<CR>", map_opts)
end

return PSQL
