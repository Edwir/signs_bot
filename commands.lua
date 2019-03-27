--[[

	Signs Bot
	=========

	Copyright (C) 2019 Joachim Stolberg

	LGPLv2.1+
	See LICENSE.txt for more information
	
	Signs Bot: Robot command interpreter

]]--

-- for lazy programmers
local S = function(pos) if pos then return minetest.pos_to_string(pos) end end
local P = minetest.string_to_pos
local M = minetest.get_meta

-- Load support for intllib.
local MP = minetest.get_modpath("signs_bot")
local I,_ = dofile(MP.."/intllib.lua")

local lib = signs_bot.lib

local tPos2Dir = {l = "l", r = "r", L = "l", R = "l", f = "f", F = "f"}
local tPos2Dirs = {
	["2"] = {"l","r"}, ["3"] = {"l","f","r"}, l = {"l"}, r = {"r"}, 
	L = {"l"}, R = {"l"}, f = {"f"}, F = {"f"}
}
local tValidLevels = {["-1"] = -1, ["0"] = 0, ["+1"] = 1}


local tCommands = {}
local SortedKeys = {}

local function check_cmnd_block(pos, mem, meta)
	local cmnd = meta:get_string("signs_bot_cmnd")
	if cmnd ~= "" then  -- command block?
		if meta:get_int("err_code") ~= 0 then -- code not valid?
			return false
		end
		local node = lib.get_node_lvm(pos)
		
		if node.name ~= "signs_bot:box" and mem.robot_param2 ~= node.param2 then -- wrong sign direction?
			return false
		end
		-- read code
		mem.lCmnd = {}
		for _,s in ipairs(string.split(cmnd, "\n")) do
			table.insert(mem.lCmnd, s)
		end
		return true
	end
	return false
end

local function trigger_sensor(pos, node)
	print("trigger_sensor")
	local meta = M(pos)
	local dest_pos = meta:get_string("dest_pos")
	local dest_idx = meta:get_int("dest_idx")
	if dest_pos ~= "" and dest_idx ~= 0 then
		minetest.registered_nodes[node.name].switch_sign_changer(minetest.string_to_pos(dest_pos), dest_idx)
	end
end

local function can_move(mem)
	local pos = minetest.find_node_near(mem.robot_pos, 1, {
			"signs_bot:bot_sensor", "signs_bot:bot_sensor_on", "group:sign_bot_sign"})
	if pos then
		local dis = vector.distance(mem.robot_pos, pos)
		local node = lib.get_node_lvm(pos)
		-- Will the bot pass the sensor?
		if dis == 1 and node.name == "signs_bot:bot_sensor_on" then
			node.name = "signs_bot:bot_sensor"
			minetest.swap_node(pos, node)
		elseif node.name == "signs_bot:bot_sensor" then
			return {pos=pos, node=node}
		else
			local pos1 = lib.next_pos(mem.robot_pos, mem.robot_param2)
			local meta = M(pos1)
			if check_cmnd_block(pos1, mem, meta) then
				return false
			else
				local pos2 = {x=pos1.x, y=pos1.y+1, z=pos1.z}
				meta = M(pos2)
				if check_cmnd_block(pos2, mem, meta) then
					return false
				end
			end
		end
	end
	return true
end

local function after_move(mem, state)
	if state ~= true then
		local dis = vector.distance(mem.robot_pos, state.pos)
		local node = lib.get_node_lvm(state.pos)
		-- Will the bot reach the sensor?
		print("after_move", dis, node.name)
		if dis == 1 then
			node.name = "signs_bot:bot_sensor_on"
			minetest.swap_node(state.pos, node)
			trigger_sensor(state.pos, node)
		end
	end
end	

--
-- Command register API function
--

-- def = {
--     params = "<lvl> <slot>",
--     description = "...",
--     check = function(param1 param2)...end,
--     func = function(base_pos, mem, param1, param2)...end,
-- }
function signs_bot.register_botcommand(name, def)
	tCommands[name] = def
	tCommands[name].name = name
	SortedKeys[#SortedKeys+1] = name
end

signs_bot.register_botcommand("move", {
	params = "<steps>",	
	description = I("Move the robot 1..9 steps forward.\nDefault value: 1"),
	check = function(steps)
		steps = tonumber(steps or "1")
		return steps > 0 and steps < 10
	end,
	func = function(base_pos, mem, steps)
		steps = tonumber(steps)
		local state = can_move(mem)
		if state then
			local new_pos = signs_bot.move_robot(mem.robot_pos, mem.robot_param2)
			if new_pos then  -- not blocked?
				mem.robot_pos = new_pos
				after_move(mem, state)
			end
			-- more than one move step?
			if steps and steps > 1 then
				steps = steps - 1
				-- add to the command table again
				table.insert(mem.lCmnd, 1, "move "..steps)
			end
		end
		return true
	end,
})

signs_bot.register_botcommand("turn_left", {
	params = "",	
	description = I("Turn the robot to the left"),
	func = function(base_pos, mem)
		mem.robot_param2 = signs_bot.turn_robot(mem.robot_pos, mem.robot_param2, "L")
		return true
	end,
})

signs_bot.register_botcommand("turn_right", {
	params = "",	
	description = I("Turn the robot to the right"),
	func = function(base_pos, mem)
		mem.robot_param2 = signs_bot.turn_robot(mem.robot_pos, mem.robot_param2, "R")
		return true
	end,
})

signs_bot.register_botcommand("turn_around", {
	params = "",	
	description = I("Turn the robot around"),
	func = function(base_pos, mem)
		mem.robot_param2 = signs_bot.turn_robot(mem.robot_pos, mem.robot_param2, "R")
		mem.robot_param2 = signs_bot.turn_robot(mem.robot_pos, mem.robot_param2, "R")
		return true
	end,
})

signs_bot.register_botcommand("backward", {
	params = "",	
	description = I("Move the robot one step back"),
	func = function(base_pos, mem)
		local new_pos = signs_bot.backward_robot(mem.robot_pos, mem.robot_param2)
		if new_pos then  -- not blocked?
			mem.robot_pos = new_pos
		end
		return true
	end,
})
	
signs_bot.register_botcommand("turn_off", {
	params = "",	
	description = I("Turn the robot off\n"..
		"and put it back in the box."),
	func = function(base_pos, mem)
		signs_bot.stop_robot(base_pos, mem)
		return false
	end,
})
	
signs_bot.register_botcommand("pause", {
	params = "<sec>",	
	description = I("Stop the robot for <sec> seconds\n(1..9999)"),
	check = function(sec)
		sec = tonumber(sec or 1)
		return sec > 0 and sec < 10000
	end,
	func = function(base_pos, mem, sec)
		-- more than one second?
		sec = tonumber(sec or 1)
		if sec and sec > 1 then
			sec = sec - 1
			-- add to the command table again
			table.insert(mem.lCmnd, 1, "pause "..sec)
		end
		return true
	end,
})
	
signs_bot.register_botcommand("move_up", {
	params = "",	
	description = I("Move the robot upwards"),
	func = function(base_pos, mem)
		local new_pos = signs_bot.robot_up(mem.robot_pos, mem.robot_param2)
		if new_pos then  -- not blocked?
			mem.robot_pos = new_pos
		end
		return true
	end,
})
	
signs_bot.register_botcommand("move_down", {
	params = "",	
	description = I("Move the robot down"),
	func = function(base_pos, mem)
		local new_pos = signs_bot.robot_down(mem.robot_pos, mem.robot_param2)
		if new_pos then  -- not blocked?
			mem.robot_pos = new_pos
		end
		return true
	end,
})
	
signs_bot.register_botcommand("take_item", {
	params = "<num> <slot>",	
	description = I("Take <num> items from a chest like node\nand put it into the item inventory.\n"..
		"Param <slot> (1..8) is optional"),
	check = function(num, slot)
		num = tonumber(num)
		if num == nil or num < 1 or num > 99 then 
			return false 
		end
		slot = tonumber(slot)
		if slot and (slot < 1 or slot > 8) then 
			return false 
		end
		return true
	end,
	func = function(base_pos, mem, num, slot)
		num = tonumber(num)
		slot = tonumber(slot)
		signs_bot.robot_take(base_pos, mem.robot_pos, mem.robot_param2, num, slot)
		return true
	end,
})
	
signs_bot.register_botcommand("add_item", {
	params = "<num> <slot>",	
	description = I("Add <num> items to a chest like node\ntaken from the item inventory.\n"..
		"Param <slot> (1..8) is optional"),
	check = function(num, slot)
		num = tonumber(num)
		if num == nil or num < 1 or num > 99 then 
			return false 
		end
		slot = tonumber(slot)
		if slot and (slot < 1 or slot > 8) then 
			return false 
		end
		return true
	end,
	func = function(base_pos, mem, num, slot)
		num = tonumber(num)
		slot = tonumber(slot)
		signs_bot.robot_add(base_pos, mem.robot_pos, mem.robot_param2, num, slot)
		return true
	end,
})
	
signs_bot.register_botcommand("place_item", {
	params = "<slot> <pos> <lvl>",	
	description = I("Place an item from the item inventory\non the specified position\n"..
		"<slot> is the inventory slot (1..8)\n"..
		"<pos> is one of: l   f   r   2   3\n"..
		"<lvl> is one of: -1   0   +1"),
	check = function(slot, pos, lvl)
		slot = tonumber(slot)
		if slot and (slot < 1 or slot > 8) then 
			return false 
		end
		local dirs = tPos2Dirs[pos]
		local level = tValidLevels[lvl]
		return dirs and level
	end,
	func = function(base_pos, mem, slot, pos, lvl)
		slot = tonumber(slot)
		local dirs = tPos2Dirs[pos]
		local level = tValidLevels[lvl]
		signs_bot.place_item(base_pos, mem.robot_pos, mem.robot_param2, slot, dirs, level)
		return true
	end,
})
	
signs_bot.register_botcommand("dig_item", {
	params = "<slot> <pos> <lvl>",	
	description = I("Dig an item on the specified position\n and add it to the item inventory\n"..
		"<slot> is the inventory slot (1..8)\n"..
		"<pos> is one of: l   f   r   2   3\n"..
		"<lvl> is one of: -1   0   +1"),
	check = function(slot, pos, lvl)
		slot = tonumber(slot)
		if slot and (slot < 1 or slot > 8) then 
			return false 
		end
		local dirs = tPos2Dirs[pos]
		local level = tValidLevels[lvl]
		return dirs and level
	end,
	func = function(base_pos, mem, slot, pos, lvl)
		slot = tonumber(slot)
		local dirs = tPos2Dirs[pos]
		local level = tValidLevels[lvl]
		signs_bot.dig_item(base_pos, mem.robot_pos, mem.robot_param2, slot, dirs, level)
		return true
	end,
})
	
signs_bot.register_botcommand("rotate_item", {
	params = "<pos> <lvl> <steps>",	
	description = I("Rotate an item on the specified position\n"..
		"<pos> is one of:  l   f   r   2   3\n"..
		"<lvl> is one of:  -1   0   +1\n"..
		"<steps> is one of:  1   2   3"),
	check = function(pos, lvl, steps)
		local dir = tPos2Dir[pos]
		local level = tValidLevels[lvl]
		steps = tonumber(steps)
		if not steps or steps < 1 or steps > 4 then
			return false
		end
		return dir and level
	end,
	func = function(base_pos, mem, pos, lvl, steps)
		local dir = tPos2Dir[pos]
		local level = tValidLevels[lvl]
		steps = tonumber(steps)
		signs_bot.rotate_item(base_pos, mem.robot_pos, mem.robot_param2, dir, level, steps)
		return true
	end,
})
	
signs_bot.register_botcommand("place_sign", {
	params = "<slot>",	
	description = I("Place a sign in front of the robot\ntaken from the signs inventory\n"..
		"<slot> is the inventory slot (1..4)"),
	check = function(slot)
		slot = tonumber(slot)
		return slot and slot > 0 and slot < 5
	end,
	func = function(base_pos, mem, slot)
		slot = tonumber(slot)
		signs_bot.place_sign(base_pos, mem.robot_pos, mem.robot_param2, slot)
		return true
	end,
})
	
signs_bot.register_botcommand("place_sign_behind", {
	params = "<slot>",	
	description = I("Place a sign behind the robot\ntaken from the signs inventory\n"..
		"<slot> is the inventory slot (1..4)"),
	check = function(slot)
		slot = tonumber(slot)
		return slot and slot > 0 and slot < 5
	end,
	func = function(base_pos, mem, slot)
		slot = tonumber(slot)
		signs_bot.place_sign_behind(base_pos, mem.robot_pos, mem.robot_param2, slot)
		return true
	end,
})
	
signs_bot.register_botcommand("dig_sign", {
	params = "<slot>",	
	description = I("Dig the sign in front of the robot\n"..
		"and add it to the signs inventory.\n"..
		"<slot> is the inventory slot (1..4)"),
	check = function(slot)
		slot = tonumber(slot)
		return slot and slot > 0 and slot < 5
	end,
	func = function(base_pos, mem, slot)
		slot = tonumber(slot)
		signs_bot.dig_sign(base_pos, mem.robot_pos, mem.robot_param2, slot)
		return true
	end,
})
	
signs_bot.register_botcommand("trash_sign", {
	params = "<slot>",	
	description = I("Dig the sign in front of the robot\n"..
		"and add the cleared sign to\nthe item iventory.\n"..
		"<slot> is the inventory slot (1..8)"),
	check = function(slot)
		slot = tonumber(slot)
		return slot and slot > 0 and slot < 5
	end,
	func = function(base_pos, mem, slot)
		slot = tonumber(slot)
		signs_bot.trash_sign(base_pos, mem.robot_pos, mem.robot_param2, slot)
		return true
	end,
})
	
signs_bot.register_botcommand("stop_robot", {
	params = "",	
	description = I("Stop the robot."),
	func = function(base_pos, mem, slot)
		mem.lCmnd = {"stop_robot"}
		return true
	end,
})

function signs_bot.check_commands(pos, text)
	--local idx = 1
	for idx,line in ipairs(string.split(text, "\n", true)) do
		local cmnd, param1, param2, param3 = unpack(string.split(line, " "))
		if cmnd ~= "--" and cmnd ~= nil then -- No comment or empty line?
			if tCommands[cmnd] then
				if tCommands[cmnd].check and not tCommands[cmnd].check(param1, param2, param3) then
					return false, I("Parameter error in line ")..idx..":\n"..
					cmnd.." "..tCommands[cmnd].params
				end
			else
				return false, I("Command error in line ")..idx..":\n"..line
			end
		end
		--idx = idx + 1
	end
	return true, I("Checked and approved")
end

function signs_bot.run_next_command(base_pos, mem)
	mem.lCmnd = mem.lCmnd or {}
	local res = nil
	while res == nil do
		local line = table.remove(mem.lCmnd, 1)
		if line then
			local cmnd, param1, param2, param3 = unpack(string.split(line, " "))
			if cmnd ~= "--" then -- No comment?
				res = tCommands[cmnd].func(base_pos, mem, param1, param2, param3)
			end
		else
			res = tCommands["move"].func(base_pos, mem)
		end

	end
	return res
end	

function signs_bot.get_help_text()
	local tbl = {}
	for idx,cmnd in ipairs(SortedKeys) do
		local item = tCommands[cmnd]
		tbl[#tbl+1] = item.name.." "..item.params
		local text = string.gsub(item.description, "\n", "\n  -- ")
		tbl[#tbl+1] = "  -- "..text
	end
	return table.concat(tbl, "\n")
end	
	
	