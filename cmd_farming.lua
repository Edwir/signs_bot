--[[

	Signs Bot
	=========

	Copyright (C) 2019 Joachim Stolberg

	LGPLv2.1+
	See LICENSE.txt for more information
	
	Bot farming commands
]]--

-- for lazy programmers
local S = function(pos) if pos then return minetest.pos_to_string(pos) end end
local P = minetest.string_to_pos
local M = minetest.get_meta

-- Load support for intllib.
local MP = minetest.get_modpath("signs_bot")
local I,_ = dofile(MP.."/intllib.lua")

local lib = signs_bot.lib

local function inv_get_item(pos, slot)
	local inv = minetest.get_inventory({type="node", pos=pos})
	return inv and lib.get_inv_items(inv, "main", slot, 1)
end

local function inv_put_item(pos, mem, name)
	local inv = minetest.get_inventory({type="node", pos=pos})
	local leftover = inv and inv:add_item("main", ItemStack(name))
	if leftover and leftover:get_count() > 0 then
		lib.drop_items(mem.robot_pos, leftover)
	end
end

local function get_pointed_thing(pos)
	local node = minetest.get_node_or_nil(pos)
	if node.name == "air" then
		local pos1 = {x=pos.x, y=pos.y-1, z=pos.z}
		node = minetest.get_node_or_nil(pos1)
		if minetest.get_item_group(node.name, "soil") >= 1 then
			return {type = "node", under = pos1, above = pos}
		end
	end
end

local function planting(base_pos, mem, slot)
	local pos = mem.pos_tbl and mem.pos_tbl[mem.steps]
	mem.steps = mem.steps + 1
	local stack = inv_get_item(base_pos, slot)
	local item = stack and signs_bot.FarmingSeed[stack:get_name()]
	local pointed_thing = get_pointed_thing(pos)
	if pointed_thing and item and item.seed then
		if not farming.place_seed(stack, nil, pointed_thing, item.seed) then
			return
		end
	end
	if stack then
		inv_put_item(pos, mem, stack:get_name())
	end
end	

signs_bot.register_botcommand("sow_seed", {
	mod = "farming",
	params = "<slot>",	
	description = I("Sow farming seeds\nin front of the robot"),
	check = function(slot)
		slot = tonumber(slot)
		return slot and slot > 0 and slot < 9
	end,
	cmnd = function(base_pos, mem, slot)
		slot = tonumber(slot)
		if not mem.steps then
			mem.pos_tbl = signs_bot.lib.gen_position_table(mem.robot_pos, mem.robot_param2, 3, 3, 0)
			mem.steps = 1
		end
		mem.pos_tbl = mem.pos_tbl or {}
		planting(base_pos, mem, slot)
		if mem.steps > #mem.pos_tbl then
			mem.steps = nil
			return lib.DONE
		end
		return lib.BUSY
	end,
})

local function harvesting(base_pos, mem)
	local pos = mem.pos_tbl and mem.pos_tbl[mem.steps]
	mem.steps = (mem.steps or 1) + 1
	
	if pos and lib.not_protected(base_pos, pos) then
		local node = minetest.get_node_or_nil(pos)
		local item = signs_bot.FarmingCrop[node.name]
		if item and item.inv_crop and item.inv_seed then
			minetest.remove_node(pos)
			inv_put_item(base_pos, mem, item.inv_crop)
			inv_put_item(base_pos, mem, item.inv_seed)
		end
	end
end

signs_bot.register_botcommand("harvest", {
	mod = "farming",
	params = "",	
	description = I("Harvest farming products\nin front of the robot\non a 3x3 field."),
	cmnd = function(base_pos, mem)
		if not mem.steps then
			mem.pos_tbl = signs_bot.lib.gen_position_table(mem.robot_pos, mem.robot_param2, 3, 3, 0)
			mem.steps = 1
		end
		mem.pos_tbl = mem.pos_tbl or {}
		harvesting(base_pos, mem)
		if mem.steps > #mem.pos_tbl then
			mem.steps = nil
			return lib.DONE
		end
		return lib.BUSY
	end,
})


local function plant_sapling(base_pos, mem, slot)
	local pos = lib.dest_pos(mem.robot_pos, mem.robot_param2, {0})
	if lib.not_protected(base_pos, pos) and soil_availabe(pos) then
		local stack = inv_get_item(base_pos, slot)
		local item = stack and signs_bot.TreeSaplings[stack:get_name()]
		if item and item.sapling then
			minetest.set_node(pos, {name = item.sapling, paramtype2 = "wallmounted", param2 = 1})
			if item.t1 ~= nil then 
				-- We have to simulate "on_place" and start the timer by hand
				-- because the after_place_node function checks player rights and can't therefore
				-- be used.
				minetest.get_node_timer(pos):start(math.random(item.t1, item.t2))
			end			
		end
	end
end	

signs_bot.register_botcommand("plant_sapling", {
	mod = "farming",
	params = "<slot>",	
	description = I("Plant a sapling\nin front of the robot"),
	check = function(slot)
		slot = tonumber(slot)
		return slot and slot > 0 and slot < 9
	end,
	cmnd = function(base_pos, mem, slot)
		slot = tonumber(slot)
		plant_sapling(base_pos, mem, slot)
		return lib.DONE
	end,
})


local CMD = [[dig_sign 1
move
harvest
sow_seed 1
backward
place_sign 1
turn_off]]

signs_bot.register_sign({
	name = "farming", 
	description = I('Sign "farming"'), 
	commands = CMD, 
	image = "signs_bot_sign_farming.png",
})

minetest.register_craft({
	output = "signs_bot:farming 2",
	recipe = {
		{"group:wood", "default:stick", "group:wood"},
		{"dye:black", "default:stick", "dye:yellow"},
		{"dye:grey", "", ""}
	}
})
