local themes = require("telescope.themes")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local entry_display = require("telescope.pickers.entry_display")
local conf = require("telescope.config").values
local resolve = require "telescope.config.resolve"

local categories
local CpMenu = require("command_palette").CpMenu

local function setup(cpMenu)
  require("command_palette").CpMenu = cpMenu or {}
  CpMenu = require("command_palette").CpMenu
end

function themes.vscode(opts)
  opts = opts or {}
  local theme_opts = {
    theme = "dropdown",
    results_title = false,
    sorting_strategy = "ascending",
    layout_strategy = "vertical",
    layout_config = {
      anchor = "N",
      prompt_position = "top",
      width = function(_, max_columns, _)
        return math.min(max_columns, 120)
      end,
      height = function(_, _, max_lines)
        return math.min(max_lines, 15)
      end,
    },
  }
  if opts.layout_config and opts.layout_config.prompt_position == "bottom" then
    theme_opts.borderchars = {
      prompt = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
      results = { "─", "│", "─", "│", "╭", "╮", "┤", "├" },
      preview = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
    }
  end
  return vim.tbl_deep_extend("force", theme_opts, opts)
end

local function table_length(T)
  local count = 0
  for _ in pairs(T) do
    count = count + 1
  end
  return count
end

local function list_of_categories()
  local results = {}
  for i = table_length(CpMenu), 1, -1 do
    results[i] = CpMenu[i][1]
  end
  return results
end

local function list_of_commands(index)
  local results = {}
  local j = 1
  for i = table_length(CpMenu[index]), 2, -1 do
    results[j] = CpMenu[index][i]
    j = j + 1
  end
  return results
end

-- picker: commands
local function commands(opts, table)
  opts = opts or {}
  pickers.new(opts, {
    prompt_title = opts.commands_title,
    finder = finders.new_table({
      results = table,
      entry_maker = function(entry)
        local results_win = vim.api.nvim_get_current_win()
        local w = vim.api.nvim_win_get_width(results_win)
        local h = vim.api.nvim_win_get_height(results_win)
        local width = conf.width or conf.layout_config.width or
            conf.layout_config[conf.layout_strategy].width or vim.o.columns
        local tel_win_width = resolve.resolve_width(width)(nil, w, h) - #conf.selection_caret
        local desc_width = math.floor(tel_win_width * 0.05)
        local command_width = 28

        -- NOTE: the width calculating logic is not exact, but approx enough
        local displayer = entry_display.create({
          separator = " ▏",
          items = {
            { width = command_width },
            { width = tel_win_width - desc_width - command_width },
            { remaining = true },
          },
        })

        local function make_display()
          return displayer({
            { entry[1] },
            { entry[2] },
          })
        end

        return {
          value = entry,
          display = make_display,
          ordinal = string.format("%s %s", entry[1], entry[2]),
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
      map("i", "<C-b>", function()
        categories(require("telescope.themes").vscode({}))
      end)
      map("n", "<C-b>", function()
        categories(require("telescope.themes").vscode({}))
      end)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        -- temporarily workaround for telescope issue: 1599.
        local selection = action_state.get_selected_entry()
        if selection.value[3] == 1 then
          vim.schedule(function()
            vim.cmd("startinsert! ")
          end)
        end
        vim.api.nvim_exec(selection.value[2], true)
      end)
      return true
    end,
  }):find()
end

categories = function(opts)
  opts = opts or {}
  pickers.new(opts, {
    prompt_title = "categories",
    finder = finders.new_table({
      results = list_of_categories(),
    }),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        -- temporarily workaround for telescope issue: 1599.
        vim.schedule(function()
          vim.cmd("startinsert! ")
        end)
        local selection = action_state.get_selected_entry()
        opts.commands_title = selection[1]
        commands(opts, list_of_commands(selection.index))
      end)
      return true
    end,
  }):find()
end

local function run()
  categories(require("telescope.themes").vscode({}))
end

return require("telescope").register_extension({
  setup = setup,
  exports = {
    -- Default when to argument is given, i.e. :Telescope command_palette
    command_palette = run,
  },
})
