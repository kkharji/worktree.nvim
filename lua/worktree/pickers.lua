R "worktree.actions"
local M = {}
local a = require "telescope.actions"
local s = require "telescope.actions.state"
local finder = require("telescope.finders").new_table
local picker = require("telescope.pickers").new
local sorter = require("telescope.config").values.generic_sorter
local maker = require("telescope.pickers.entry_display").create
local actions = require "worktree.actions"
local get, perform, pactions = actions.get, actions.perform, actions.picker
local dropdown, commit_choices

if user then
  dropdown = user.pack.telescope.themes.minimal { layout_config = { width = 0.4, height = 0.2 } }
else
  return {}
end

-- TODO: read a list of branch types and their template either using a user
--- defined function or default sample. Skip reading from old dotfiles.
M.pick_branch_type = function(opts)
  -- local dd = dropdown { layout_config = { width = 0.4, height = 0.3 } }
  picker(dropdown, {
    prompt_title = opts.title,
    prompt_prefix = "",
    -- initial_mode = "normal",
    finder = finder {
      results = opts.choices,
      entry_maker = function(entry)
        entry.ordinal = entry.title
        entry.display = function(e)
          return maker {
            separator = " ",
            hl_chars = { ["|"] = "TelescopeResultsNumber" },
            items = { { width = 20 }, { remaining = true } },
          } {
            { e.title, "TSLabel" },
            { e.desc, "TelescopeResultsMethod" },
          }
        end

        return entry
      end,
    },
    sorter = sorter {},
    attach_mappings = function(_, _)
      a.select_default:replace(function(bufnr)
        a.close(bufnr)
        return opts.on_submit(s.get_selected_entry())
      end)
      return true
    end,
  }):find()
end

---Pick branch merge type
---@param cb any
M.pick_branch_merge_type = function(cb)
  -- local dd = dropdown { layout_config = { width = 0.3, height = 0.2 } }
  picker(dropdown, {
    prompt_title = "Pick Merge type",
    prompt_prefix = "",
    -- initial_mode = "normal",
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
            { e.type, "TSTag" },
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

M.switcher = function(opts)
  -- local dd = dropdown { layout_config = { width = 0.4, height = 0.2 } }
  local cwd = vim.loop.cwd()
  local parts = vim.split(cwd, "/")
  local name = parts[#parts]
  picker(vim.tbl_extend("keep", opts or {}, dropdown), {
    prompt_prefix = "",
    prompt_title = name .. " Worktree",
    sorter = sorter {},
    initial_mode = "normal",
    attach_mappings = function(_, map)
      map("i", "<C-n>", pactions.create_branch)
      map("n", "N", pactions.create_branch)

      map("i", "<C-d>", pactions.delete_branch)
      map("n", "d", pactions.delete_branch)
      --- TODO: delete without confirmation

      map("i", "<C-s>", pactions.merge_branch)
      map("n", "m", pactions.merge_branch)

      map("i", "<C-o>", pactions.open_pr_in_web)
      map("n", "<C-o>", pactions.open_pr_in_web)
      map("n", "<leader>so", pactions.open_pr_in_web)

      map("i", "<C-p>", pactions.create_pr)
      map("n", "<C-p>", pactions.create_pr)
      map("n", "<leader>gp", pactions.create_pr)

      map("i", "<C-e>", pactions.edit_branch)
      map("n", "e", pactions.edit_branch)

      map("i", "<CR>", pactions.switch_branch)
      map("n", "<CR>", pactions.switch_branch)
      return true
    end,
    finder = finder {
      results = get.branches(cwd),
      entry_maker = function(entry)
        entry.ordinal = entry.name
        entry.display = function(e)
          return maker {
            separator = " ",
            hl_chars = { ["|"] = "TelescopeResultsNumber" },
            items = { { width = 40 }, { width = 20 }, { remaining = true } },
          } {
            { e.subject, e.current and "TSLabel" or "TelescopeResultsMethod" },
            { e.scope, "TSTag" },
            { e.since, "TSComment" },
          }
        end
        return entry
      end,
    },
  }):find()
end

return M
