if not pcall(require, "telescope") then
  vim.cmd [[ echom 'Cannot load `telescope`' ]]
  return
end

local M = {}
local a = require "telescope.actions"
local s = require "telescope.actions.state"
local finder = require("telescope.finders").new_table
local picker = require("telescope.pickers").new
local sorter = require("telescope.config").values.generic_sorter
local maker = require("telescope.pickers.entry_display").create
local dropdown, commit_choices

if user then
  dropdown = user.pack.telescope.themes.minimal
  commit_choices = user.vars.commit_choices
else
  return {}
end

-- TODO: read a list of branch types and their template either using a user
--- defined function or default sample. Skip reading from old dotfiles.
M.pick_branch_type = function(title, cb)
  local dd = dropdown { layout_config = { width = 0.4, height = 0.3 } }
  picker(dd, {
    prompt_prefix = title,
    finder = finder {
      results = commit_choices(),
      entry_maker = function(entry)
        entry.shortcut = "(" .. entry.shortcut .. ")"
        entry.ordinal = entry.name
        entry.display = function(e)
          return maker {
            separator = " ",
            hl_chars = { ["|"] = "TelescopeResultsNumber" },
            items = { { width = 5 }, { width = 12 }, { remaining = true } },
          } {
            { e.shortcut, "TelescopeResultsNumber" },
            { e.name, "TelescopeResultsNumber" },
            { e.description, "TelescopeResultsMethod" },
          }
        end

        return entry
      end,
    },
    sorter = sorter {},
    attach_mappings = function(_, map)
      a.select_default:replace(function(bufnr)
        a.close(bufnr)
        return cb(s.get_selected_entry())
      end)
      local choices = commit_choices()
      for _, choice in ipairs(choices) do
        if choice.shortcut then
          map("i", choice.shortcut, function(bufnr)
            a.close(bufnr)
            return cb(choice)
          end)
        end
      end

      return true
    end,
  }):find()
end

---Pick branch merge type
---@param cb any
M.pick_branch_merge_type = function(cb)
  local dd = dropdown { layout_config = { width = 0.3, height = 0.2 } }
  picker(dd, {
    prompt_prefix = "Pick merge type> ",
    sorter = sorter {},
    finder = finder {
      results = {
        { type = "squash", description = "squash commits to one commit." },
        { type = "merge", description = "rebase with a merge commit." },
        { type = "rebase", description = "rebase and add this branch into the base branch" },
      },
      entry_maker = function(entry)
        entry.ordinal = entry.type
        entry.display = function(e)
          return maker {
            separator = " ",
            hl_chars = { ["|"] = "TelescopeResultsNumber" },
            items = { { width = 12 }, { remaining = true } },
          } {
            { e.type, "TelescopeResultsNumber" },
            { e.description, "TelescopeResultsMethod" },
          }
        end

        return entry
      end,
    },
    attach_mappings = function()
      a.select_default:replace(function(bufnr)
        a.close(bufnr)
        return cb(s.get_selected_entry())
      end)

      return true
    end,
  }):find()
end

return M
