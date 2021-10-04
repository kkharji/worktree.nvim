local Input = require "nui.input"
local event = require("nui.utils.autocmd").event

local new = function(opts)
  local window_opts = {
    position = "49%",
    size = { width = 40, height = 1 },
    relative = "editor",
    -- position = { row = 3, col = 1 },
    border = {
      highlight = "LspSagaHoverBorder",
      style = "rounded",
      text = { top = opts.heading, top_align = "center", highlight = "Bold" },
    },
    win_options = { winblend = 10, winhighlight = "Normal:Normal" },
  }

  return Input(window_opts, {
    prompt = " ",
    default_value = opts.default or "",
    on_close = opts.close,
    on_submit = opts.submit,
  })
end

local call = function(opts)
  opts.close = function()
    (opts.on_close or function() end)(true)
  end
  opts.submit = function(value)
    opts.on_submit(value)
  end
  local prompt = new(opts)
  prompt:mount()
  prompt:map("i", "<esc>", prompt.input_props.on_close, {})
  prompt:on(event.BufLeave, prompt.input_props.on_close)
  vim.api.nvim_feedkeys("i", "t", false)
end

return call
