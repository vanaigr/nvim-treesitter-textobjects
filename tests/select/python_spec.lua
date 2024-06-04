local Runner = require("tests.select.common").Runner

local run = Runner:new(it, "tests/select/python", {
  tabstop = 4,
  shiftwidth = 4,
  softtabstop = 0,
  expandtab = true,
})

local function run_tests()
  run:compare_cmds("aligned_indent.py", { row = 1, col = 0, cmds = { "daa", "vaad", "caa" } })
  run:compare_cmds("aligned_indent.py", { row = 1, col = 10, cmds = { "dia", "viad", "cia" } })
  run:compare_cmds("aligned_indent.py", {
    row = 1,
    col = 0,
    cmds = {
      "diahx",
      "viadhx",
      "cia<bs>",
    },
  })
  -- select using built-in finds (f, F, t, T)
  run:compare_cmds("aligned_indent.py", { row = 1, col = 0, cmds = { "dfi", "vfid", "cfi" } })
  -- select using move
  run:compare_cmds("aligned_indent.py", { row = 1, col = 0, cmds = { "d]a", "v]ad", "c]a" } })
  run:compare_cmds("selection_mode.py", { row = 2, col = 4, cmds = { "dam", "dVam", "vamd", "Vamd" } })
  run:compare_cmds("selection_mode.py", { row = 5, col = 8, cmds = { "dVao", "dao" } }, nil, false)
end

describe("command equality Python:", run_tests)
describe("command equality Python with selection=exclusive:", function()
  vim.api.nvim_set_option_value("selection", "exclusive", {})
  run_tests()
  vim.api.nvim_set_option_value("selection", "inclusive", {})
end)
