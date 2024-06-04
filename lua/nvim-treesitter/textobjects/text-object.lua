-- based on https://github.com/vanaigr/motion.nvim at 1ad88814f63882ae3a99f3527998f660a848c7bc

local Lines = {
  __index = function(tab, k)
    local line = vim.api.nvim_buf_get_lines(0, k - 1, k, true)[1]
    rawset(tab, k, line)
    return line
  end,
}

local Context = {
  __index = function(tab, k)
    if k == "virtualedit" then
      local virtualedit = vim.api.nvim_get_option_value("virtualedit", {})
      local ve = vim.split(virtualedit, ",", { plain = true })

      local c = false
      for _, value in ipairs(ve) do
        if value == "all" or value == "onemore" then
          c = true
          break
        end
      end

      rawset(tab, k, c)
      return c
    elseif k == "selection" then
      local v = vim.api.nvim_get_option_value("selection", {})
      rawset(tab, k, v)
      return v
    end
  end,
}

--- @return table
local function create_context()
  return setmetatable({
    lines = setmetatable({}, Lines),
    lines_count = vim.api.nvim_buf_line_count(0),
  }, Context)
end

--- Modifies given position to be clamped to the buffer and line length.
---
--- @param pos table<integer, integer>
--- @param context table
--- @return table<integer, integer>: `pos`
local function clamp_pos(pos, context)
  local lines_count = context.lines_count

  if pos[1] < 1 then
    pos[1] = 1
    pos[2] = 0
  elseif pos[1] > lines_count then
    pos[1] = lines_count
    pos[2] = #context.lines[lines_count]
  elseif pos[2] < 0 then
    pos[2] = 0
  else
    pos[2] = math.min(pos[2], #context.lines[pos[1]])
  end

  return pos
end

--- Checks whether `a` < `b`.
--- @param a table<integer, integer>
--- @param b table<integer, integer>
--- @return boolean
local function pos_lt(a, b)
  return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2])
end

--- Checks whether given 2 positions are on the same character.
--- Positions are (1, 0) indexed, clamped.
---
--- @param p1 table<integer, integer>
--- @param p2 table<integer, integer>
--- @param context table
--- @return boolean
local function is_same_char(p1, p2, context)
  if p1[1] ~= p2[1] then
    return false
  end
  if p1[2] == p2[2] then
    return true
  end
  local line = context.lines[p1[1]]
  return vim.fn.charidx(line, p1[2]) == vim.fn.charidx(line, p2[2])
end

--- Modifies `pos` to point to the first byte of the character that contains it.
--- Composing characters are considered a part of one character.
---
--- @param pos table<integer, integer> (1, 0) indexed clamped position
--- @param context table
--- @return nil: not specified, may change
local function move_to_cur(pos, context)
  local lines = context.lines
  local line = lines[pos[1]]

  local ci = vim.fn.charidx(line, pos[2])
  if ci < 0 then
    pos[2] = #line
  else
    local bi = vim.fn.byteidx(line, ci)
    assert(bi >= 0)
    pos[2] = bi
  end
end

--- Modifies `pos` to point to the first byte of the previous character.
--- Composing characters are considered a part of one character.
---
--- @param pos table<integer, integer> (1, 0) indexed clamped position
--- @param context table
--- @return boolean: if `pos` points to the next char (false if would be OOB; `pos` is normalized)
local function move_to_prev(pos, context)
  local lines = context.lines
  local line = lines[pos[1]]

  if #line == 0 then
    if pos[1] == 1 then
      return false
    else
      pos[1] = pos[1] - 1
      pos[2] = #lines[pos[1]]
      return true
    end
  elseif pos[2] == #line then
    local ci = vim.fn.charidx(line, #line - 1)
    assert(ci >= 0)
    local bi = vim.fn.byteidx(line, ci)
    assert(bi >= 0)
    pos[2] = bi
    return true
  end

  local ci = vim.fn.charidx(line, pos[2])
  assert(ci >= 0)
  if ci == 0 then
    if pos[1] == 1 then
      return false
    end
    pos[1] = pos[1] - 1
    pos[2] = #lines[pos[1]]
  else
    local bi = vim.fn.byteidx(line, ci - 1)
    assert(bi >= 0)
    pos[2] = bi
  end

  return true
end

local M = {}

--- Modifies endpoints `p1` and `p2` for a text object.
--- Positions are (1, 0) indexed, end-exclusive.
---
--- @param p1 table<integer, integer>
--- @param p2 table<integer, integer>
--- @param opts { mode: "v" | "V" | "" }
--- @return boolean: whether the selection can be started.
function M.calc_endpoints(p1, p2, opts)
  local context = create_context()

  clamp_pos(p1, context)
  clamp_pos(p2, context)

  local pos_f, pos_l
  if pos_lt(p1, p2) then
    pos_f, pos_l = p1, p2
  else
    pos_f, pos_l = p2, p1
  end

  local mode = opts.mode
  if mode == "v" then
    local sel = context.selection
    if sel == "exclusive" then
      return not is_same_char(p1, p2, context)
    end

    move_to_prev(pos_l, context)

    if sel == "inclusive" or (sel == "old" and context.virtualedit) then
      return not pos_lt(pos_l, pos_f)
    end

    assert(sel == "old")
    local lines = context.lines

    move_to_cur(pos_f, context)
    if pos_f[2] > 0 and pos_f[2] >= #lines[pos_f[1]] then
      if pos_f[1] >= context.lines_count then
        return false
      end
      pos_f[1] = pos_f[1] + 1
      pos_f[2] = 0
    end

    if pos_l[2] > 0 and pos_l[2] >= #lines[pos_l[1]] then
      pos_l[2] = #lines[pos_l[1]] - 1
    end

    return not pos_lt(pos_l, pos_f)
  elseif mode == "V" then
    move_to_prev(pos_l, context)
    return not pos_lt(pos_l, pos_f)
  elseif mode == "" then
    if context.selection == "exclusive" then
      return not is_same_char(p1, p2, context)
    end
  end

  return false
end

return M
