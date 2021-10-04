local Menu = require "nui.menu"

local call = function(opts)
  local lines = {}
  for i, line in ipairs(opts.choices) do
    if type(line) == "table" and line.heading then
      lines[i] = Menu.separator(string.format("[%s]", line.heading))
    else
      lines[i] = Menu.item(line)
    end
  end

  local menu = Menu({
    relative = "editor",
    position = "49%",
    -- position = { row = 1, col = 0, },
    size = { width = opts.width or 90, height = opts.height or 10 },
    border = {
      style = "rounded",
      highlight = "FloatBorder",
      text = {
        top = opts.heading,
        top_align = "center",
      },
    },
    highlight = "Normal:Normal",
  }, {
    lines = lines,
    max_width = 40,
    separator = {
      char = "-",
      text_align = "left",
    },
    keymap = {
      focus_next = { "j", "<Down>", "<Tab>" },
      focus_prev = { "k", "<Up>", "<S-Tab>" },
      close = { "<Esc>", "<C-c>", "sd", "q" },
      submit = { "<CR>", "<Space>" },
    },
    on_close = function()
      opts.on_close(true)
    end,
    on_submit = function(item)
      opts.on_close(false, item)
    end,
  })
  menu:mount()
end
return call
