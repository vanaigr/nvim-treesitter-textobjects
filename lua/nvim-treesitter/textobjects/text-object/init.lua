-- based on https://github.com/vanaigr/motion.nvim at 1ad88814f63882ae3a99f3527998f660a848c7bc

local u = require('nvim-treesitter.textobjects.text-object.util')

local M = {}

M.util = u

--- Modifies endpoints from range [`p1`, `p2`) or [`p2`, `p1`)
--- for charwise visual selection. Positions are (1, 0) indexed.
---
--- @param p1 table<integer, integer>
--- @param p2 table<integer, integer>
--- @param context table? Context from `create_context()`
--- @return boolean: Whether the selection can be created.
function M.range_to_visual(p1, p2, context)
  if not context then context = u.create_context() end
  local lines = context.lines
  local lines_count = context.lines_count

  u.clamp_pos(p1, context)
  u.clamp_pos(p2, context)

  local sel = context.selection
  if sel == 'exclusive' then
    return not u.is_same_char(p1, p2, context)
  end

  local pos_f, pos_l
  if u.pos_lt(p1, p2) then pos_f, pos_l = p1, p2
  else pos_f, pos_l = p2, p1 end

  u.move_to_cur(pos_f, context)
  u.move_to_prev(pos_l, context)

  -- Note: old + virtualedit ~= inclusive  (if old and ends in EOL, it is ignored)
  if sel == 'inclusive' or (sel == 'old' and context.virtualedit) then
    return not u.pos_lt(pos_l, pos_f)
  end

  assert(sel == 'old')

  if pos_f[2] > 0 and pos_f[2] >= #lines[pos_f[1]] then
    if pos_f[1] >= lines_count then return false end
    pos_f[1] = pos_f[1] + 1
    pos_f[2] = 0
  end

  if pos_l[2] > 0 and pos_l[2] >= #lines[pos_l[1]] then
    pos_l[2] = #lines[pos_l[1]] - 1
  end

  return not u.pos_lt(pos_l, pos_f)
end

--- Modifies endpoints `p1` and `p2` from range for a text object.
--- Positions are (1, 0) indexed, end-exclusive.
---
--- @param p1 table<integer, integer>
--- @param p2 table<integer, integer>
--- @param opts { mode: "v" | "V" | "", context: table }
--- @return boolean: whether the selection can be started.
function M.calc_endpoints(p1, p2, opts)
  local mode = opts.mode
  local context = opts.context
  if mode == 'v' then
    return M.range_to_visual(p1, p2, context)
  elseif mode == 'V' then
    u.clamp_pos(p1, context)
    u.clamp_pos(p2, context)
    return true
  else
    assert(mode == '')

    u.clamp_pos(p1, context)
    u.clamp_pos(p2, context)

    if context.selection == 'exclusive' then
      return not u.is_same_char(p1, p2, context)
    else
      return false
    end
  end
end

return M
