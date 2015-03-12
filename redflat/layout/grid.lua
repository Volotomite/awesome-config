-----------------------------------------------------------------------------------------------------------------------
--                                               RedFlat grid layout                                                 --
-----------------------------------------------------------------------------------------------------------------------
-- Floating layout with discrete geometry
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local beautiful = require("beautiful")

local ipairs = ipairs
local pairs = pairs
local math = math

local awful = require("awful")
local hasitem = awful.util.table.hasitem
local moveresize = awful.client.moveresize

-- Initialize tables for module
-----------------------------------------------------------------------------------------------------------------------
local grid = {}
grid.name = "grid"

-- default keys
grid.keys = {
	move_up    = { "Up" },
	move_down  = { "Down" },
	move_left  = { "Left" },
	move_right = { "Right" },
	resize_up    = { "k", "K", "KP_Up", "8" },
	resize_down  = { "j", "J", "KP_Down", "2" },
	resize_left  = { "h", "H", "KP_Left", "4" },
	resize_right = { "l", "L", "KP_Right", "6" },
	exit = { "Escape", "Super_L" },
	mod  = { rail = "Control", reverse = "Shift" }
}

local data = {}

-- Support functions
-----------------------------------------------------------------------------------------------------------------------

local function compare(a ,b) return a < b end

-- Calculate cell geometry
------------------------------------------------------------
local function cell(wa, cellnum)
	local cell = {
		x = wa.width  / cellnum.x,
		y = wa.height / cellnum.y
	}

	-- adapt cell table to work with geometry prop
	cell.width = cell.x
	cell.height = cell.y

	return cell
end

-- Grid rounding
------------------------------------------------------------
local function round(a, n)
	return n * math.floor((a + n / 2) / n)
end

-- Client geometry correction by border width
------------------------------------------------------------
local function size_correction(c, geometry, is_restore)
	local sign = is_restore and - 1 or 1
	local bg = sign * 2 * c.border_width

    if geometry.width  then geometry.width  = geometry.width  - bg end
    if geometry.height then geometry.height = geometry.height - bg end
end

local function fullgeometry(c, g)
	local ng

	if g then
		if g.width  and g.width  <= 1 then return end
		if g.height and g.height <= 1 then return end

		size_correction(c, g, false)
		ng = c:geometry(g)
	else
		ng = c:geometry()
	end

	size_correction(c, ng, true)

	return ng
end

-- Fit client into grid
------------------------------------------------------------
local function fit_cell(g, cell)
	local ng = {}

	for k, v in pairs(g) do
		ng[k] = math.ceil(round(v, cell[k]))
	end

	return ng
end

-- Check geometry difference
------------------------------------------------------------
local function is_diff(g1, g2, cell)
	for k, v in pairs(g1) do
		if math.abs(g2[k] - v) >= cell[k] then return true end
	end

	return false
end

-- Place mouse pointer on window corner
------------------------------------------------------------
local function set_mouse_on_corner(g, corner)
	local mc = {}

	if     corner == "bottom_right" then mc = { x = g.x + g.width, y = g.y + g.height }
	elseif corner == "bottom_left"  then mc = { x = g.x          , y = g.y + g.height }
	elseif corner == "top_right"    then mc = { x = g.x + g.width, y = g.y }
	elseif corner == "top_left"     then mc = { x = g.x          , y = g.y }
	end

	mouse.coords(mc)
end

-- Move client
--------------------------------------------------------------------------------
local function move_to(data, dir, mod)
	local ng = {}
	local g = fullgeometry(data.c, g)
	local is_rail = hasitem(mod, grid.keys.mod.rail) ~= nil

	if dir == "left" then
		if is_rail then
			for i = #data.rail.x, 1, - 1 do
				if data.rail.x[i] < g.x then
					ng.x = data.rail.x[i]
					break
				end
			end
		else
			ng.x = g.x - data.cell.x
		end
	elseif dir == "right" then
		if is_rail then
			for i = 1, #data.rail.x  do
				if data.rail.x[i] > g.x + g.width + 1 then
					ng.x = data.rail.x[i] - g.width
					break
				end
			end
		else
			ng.x = g.x + data.cell.x
		end
	elseif dir == "up" then
		if is_rail then
			for i = #data.rail.y, 1, - 1  do
				if data.rail.y[i] < g.y then
					ng.y = data.rail.y[i]
					break
				end
			end
		else
			ng.y = g.y - data.cell.y
		end
	elseif dir == "down" then
		if is_rail then
			for i = 1, #data.rail.y  do
				if data.rail.y[i] > g.y + g.height + 1 then
					ng.y = data.rail.y[i] - g.height
					break
				end
			end
		else
			ng.y = g.y + data.cell.y
		end
	end

	fullgeometry(data.c, ng)
end

-- Resize client
--------------------------------------------------------------------------------
function resize_to(data, dir, mod)
	local ng = {}
	local g = fullgeometry(data.c)
	local is_reverse = hasitem(mod, grid.keys.mod.reverse) ~= nil
	local is_rail = hasitem(mod, grid.keys.mod.rail) ~= nil
	local sign = is_reverse and -1 or 1

	if dir == "up" then
		if is_rail then
				-- select loop direction (from min to max or from max to min)
				local f, l, s = unpack(is_reverse and { 1, #data.rail.y, 1 } or { #data.rail.y, 1, - 1 })
				for i = f, l, s do
					if is_reverse and data.rail.y[i] > g.y or not is_reverse and data.rail.y[i] < g.y then
						ng = { y = data.rail.y[i], height = g.height + g.y - data.rail.y[i] }
						break
					end
				end
		else
			ng = { y = g.y - sign * data.cell.y, height = g.height + sign * data.cell.y }
		end
	elseif dir == "down" then
		if is_rail then
				local f, l, s = unpack(is_reverse and { #data.rail.y, 1, - 1 } or { 1, #data.rail.y, 1 })
				for i = f, l, s do
					if is_reverse and data.rail.y[i] < (g.y + g.height - 1)
					   or not is_reverse and data.rail.y[i] > (g.y + g.height + 1) then
						ng = { height = data.rail.y[i] - g.y }
						break
					end
				end
		else
			ng = { height = g.height + sign * data.cell.y }
		end
	elseif dir == "left" then
		if is_rail then
				local f, l, s = unpack(is_reverse and { 1, #data.rail.x, 1 } or { #data.rail.x, 1, - 1 })
				for i = f, l, s do
					if is_reverse and data.rail.x[i] > g.x or not is_reverse and data.rail.x[i] < g.x then
						ng = { x = data.rail.x[i], width = g.width + g.x - data.rail.x[i] }
						break
					end
				end
		else
			ng = { x = g.x - sign * data.cell.x, width = g.width + sign * data.cell.x }
		end
	elseif dir == "right" then
		if is_rail then
				local f, l, s = unpack(is_reverse and { #data.rail.x, 1, - 1 } or { 1, #data.rail.x, 1 })
				for i = f, l, s do
					if is_reverse and data.rail.x[i] < (g.x + g.width)
					   or not is_reverse and data.rail.x[i] > (g.x + g.width + 1) then
						ng = { width = data.rail.x[i] - g.x }
						break
					end
				end
		else
			ng = { width = g.width + sign * data.cell.x }
		end
	end

	fullgeometry(data.c, ng)
end

-- Keygrabber
-----------------------------------------------------------------------------------------------------------------------
data.keygrabber = function(mod, key, event)
	if event == "press" then return false
	elseif hasitem(grid.keys.exit,  key) then awful.keygrabber.stop(data.keygrabber)
	elseif hasitem(grid.keys.move_up, key) then move_to(data, "up", mod)
	elseif hasitem(grid.keys.move_down, key) then move_to(data, "down", mod)
	elseif hasitem(grid.keys.move_left, key) then move_to(data, "left", mod)
	elseif hasitem(grid.keys.move_right, key) then move_to(data, "right", mod)
	elseif hasitem(grid.keys.resize_up, key) then resize_to(data, "up", mod)
	elseif hasitem(grid.keys.resize_down, key) then resize_to(data, "down", mod)
	elseif hasitem(grid.keys.resize_left, key) then resize_to(data, "left", mod)
	elseif hasitem(grid.keys.resize_right, key) then resize_to(data, "right", mod)
	else return false
	end
end

-- Tile function
-----------------------------------------------------------------------------------------------------------------------
function grid.arrange(p)

    -- theme vars
	local cellnum = beautiful.cellnum or { x = 100, y = 60 }

    -- aliases
    local wa = p.workarea
    local cls = p.clients

    -- nothing to tile here
    if #cls == 0 then return end

	-- calculate cell
	data.cell = cell(wa, cellnum)

	-- tile
	for i, c in ipairs(cls) do
		local g = fullgeometry(c)

		g = fit_cell(g, data.cell)
		fullgeometry(c, g)
	end
end

-- Mouse moving function
-----------------------------------------------------------------------------------------------------------------------
function grid.mouse_move_handler(c, _mouse, dist)
	local g = c:geometry()

	for _, crd in ipairs({ "x", "y" }) do
		local d = _mouse[crd] - g[crd] - dist[crd]
		if math.abs(d) >= data.cell[crd] then
			g[crd] = g[crd] + d
		end
	end

	c:geometry(g)
end

-- Mouse resizing function
-----------------------------------------------------------------------------------------------------------------------
function grid.mouse_resize_handler(c, corner, x, y)
	local g = fullgeometry(c)
	local cg = g

	set_mouse_on_corner(g, corner)

	mousegrabber.run(
		function (_mouse)
			 for k, v in ipairs(_mouse.buttons) do
				if v then
					local ng
					if corner == "bottom_right" then
						ng = {
							width  = _mouse.x - g.x,
							height = _mouse.y - g.y
						}
					elseif corner == "bottom_left" then
						ng = {
							x = _mouse.x,
							width  = (g.x + g.width) - _mouse.x,
							height = _mouse.y - g.y
						}
					elseif corner == "top_left" then
						ng = {
							x = _mouse.x,
							y = _mouse.y,
							width  = (g.x + g.width)  - _mouse.x,
							height = (g.y + g.height) - _mouse.y
						}
					else
						ng = {
							y = _mouse.y,
							width  = _mouse.x - g.x,
							height = (g.y + g.height) - _mouse.y
						}
					end

					if ng.width  <= 0 then ng.width  = nil end
					if ng.height <= 0 then ng.height = nil end
					if c.maximized_horizontal then ng.width  = g.width  ng.x = g.x end
					if c.maximized_vertical   then ng.height = g.height ng.y = g.y end

					if is_diff(ng, cg, data.cell) then
						cg = fullgeometry(c, ng)
					end

					return true
				end
			end
			return false
		end,
		corner .. "_corner"
	)
end

-- Keyboard handler function
-----------------------------------------------------------------------------------------------------------------------
function grid.key_handler(c)
    local wa = screen[c.screen].workarea
    local cls = awful.client.visible(c.screen)

	data.c = c or client.focus
	data.rail = { x = { wa.x, wa.x + wa.width }, y = { wa.y, wa.y + wa.height } }
	table.remove(cls, hasitem(cls, c))

	for i, v in ipairs(cls) do
		local lg = fullgeometry(v)
		local xr = lg.x + lg.width
		local yb = lg.y + lg.height

		if not hasitem(data.rail.x, lg.x) then table.insert(data.rail.x, lg.x) end
		if not hasitem(data.rail.x, xr)   then table.insert(data.rail.x, xr)   end
		if not hasitem(data.rail.y, lg.y) then table.insert(data.rail.y, lg.y) end
		if not hasitem(data.rail.y, yb)   then table.insert(data.rail.y, yb)   end
	end

	table.sort(data.rail.x, compare)
	table.sort(data.rail.y, compare)

	awful.keygrabber.run(data.keygrabber)
end

-- End
-----------------------------------------------------------------------------------------------------------------------
return grid
