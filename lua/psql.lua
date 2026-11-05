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
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_win_set_buf(win, buf)

  -- remember new buffer for later to be able to close it
  table.insert(query_result_buffers, buf)

  -- format query into a single line for buffer display
  local query_lines = vim.split(query, '\n')
  local display_parts = {}
  for _, line in ipairs(query_lines) do
    local trimmed = string.gsub(line, '^%s*(.-)%s*$', '%1')
    if trimmed ~= '' then
      trimmed = string.gsub(trimmed, '%-%-%s*(.-)$', '/* %1 */')
      table.insert(display_parts, trimmed)
    end
  end
  local display_query = table.concat(display_parts, ' ')

  -- show "Running ..." text until query is finished executing
  vim.api.nvim_buf_set_lines(buf, 0, -1, true, {'# Running...', display_query, ''})
  vim.cmd('redraw')

  -- save query to a temp file
  local tmp_file = os.tmpname()
  local f = io.open(tmp_file, 'w+')
  f:write('\\set QUIET 1 \n')            -- no console output for the following commands
  f:write('\\timing on \n')              -- show timing of queries
  f:write('\\pset null (NULL) \n')       -- show nulls as "(NULL)"
  f:write('\\pset linestyle unicode \n') -- use prettier lines inside the table
  f:write('\\pset border 2 \n')          -- show pretty lines outside the table
  f:write(query)
  f:write('\n')
  f:close()

  -- execute query
  local result = vim.fn.systemlist('psql ' .. PSQL.config.database_name .. ' -f ' .. tmp_file)

  os.remove(tmp_file)

  -- replace result buffer with query results
  vim.api.nvim_buf_set_lines(buf, 0, -1, true, {display_query, ''})
  vim.api.nvim_buf_set_lines(buf, -1, -1, true, result)
end

function PSQL.query_current_line()
  local line_number = vim.api.nvim_win_get_cursor(0)[1]
  local query = vim.api.nvim_buf_get_lines(0, line_number - 1, line_number, false)

  query = query[1]
  return run_query(query)
end

function PSQL.query_selection()
  local selection_start = vim.api.nvim_buf_get_mark(0, "<")
  local selection_end = vim.api.nvim_buf_get_mark(0, ">")

  local line1 = selection_start[1]
  local col1 = selection_start[2]
  local line2 = selection_end[1]
  local col2 = selection_end[2] + 1

  if line1 == 0 or line2 == 0 then
    print('psql plugin: no selection found')
    return
  end

  if line1 > line2 or (line1 == line2 and col1 > col2) then
    line1, line2 = line2, line1
    col1, col2 = col2, col1
  end

  local total_lines = vim.api.nvim_buf_line_count(0)
  line1 = math.max(1, math.min(line1, total_lines))
  line2 = math.max(1, math.min(line2, total_lines))

  local lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
  if #lines == 0 then
    print('psql plugin: selection is empty')
    return
  end

  local query = ''

  if line2 == line1 then
    query = string.sub(lines[1], col1+1, col2)
  else
    query = string.sub(lines[1], col1+1)

    for i = 2, #lines - 1 do
      query = query .. '\n' .. lines[i]
    end

    local last_line = lines[#lines]
    query = query .. '\n' .. string.sub(last_line, 1, col2)
  end

  -- debug info. In case I need it again, to not have to look it up
  -- query = string.format("/* block selection %s:%s, %s:%s */", line1, col1, line2, col2) .. query
  return run_query(query)
end

function PSQL.query_paragraph()
  local line1 = vim.api.nvim_buf_get_mark(0, "(")[1]
  local line2 = vim.api.nvim_buf_get_mark(0, ")")[1]

  local lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
  local query = table.concat(lines, '\n')

  return run_query(query)
end

function PSQL.close_latest_result()
  local buf = table.remove(query_result_buffers)
  if buf == nil then return end

  vim.cmd('bd ' .. buf)
end

function PSQL.close_all_results()
  while #query_result_buffers > 0 do
    local buf = table.remove(query_result_buffers)

    vim.cmd('bd ' .. buf)
  end
end

function PSQL.setup(config)
  PSQL.config = vim.tbl_extend('force', PSQL.config, config or {})

  if PSQL.config.database_name == '' then
    error('psql plugin: database_name was not provided')
  end

  local map_opts = {noremap = true, silent = true, nowait = true}
  vim.api.nvim_set_keymap('n', PSQL.config.execute_paragraph, ":lua require('psql').query_paragraph()<CR>", map_opts)
  vim.api.nvim_set_keymap('n', PSQL.config.execute_line, ":lua require('psql').query_current_line()<CR>", map_opts)
  vim.api.nvim_set_keymap('v', PSQL.config.execute_selection, ":lua require('psql').query_selection()<CR>", map_opts)

  vim.api.nvim_set_keymap('n', PSQL.config.close_latest_result, ":lua require('psql').close_latest_result()<CR>", map_opts)
  vim.api.nvim_set_keymap('n', PSQL.config.close_all_results, ":lua require('psql').close_all_results()<CR>", map_opts)
end

return PSQL
