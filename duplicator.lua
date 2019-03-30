--[[

	Signs Bot
	=========

	Copyright (C) 2019 Joachim Stolberg

	LGPLv2.1+
	See LICENSE.txt for more information
	
	Signs Bot: Signs duplicator

]]--

-- for lazy programmers
local S = function(pos) if pos then return minetest.pos_to_string(pos) end end
local P = minetest.string_to_pos
local M = minetest.get_meta

-- Load support for intllib.
local MP = minetest.get_modpath("signs_bot")
local I,_ = dofile(MP.."/intllib.lua")


local formspec = "size[8,7.3]"..
	default.gui_bg..
	default.gui_bg_img..
	default.gui_slots..
	"label[0.3,0;"..I("Input:").."]"..
	"list[context;inp;3,0;1,1;]"..
	"label[0.3,1;"..I("Template:").."]"..
	"list[context;temp;3,1;1,1;]"..
	"label[0.3,2;"..I("Output:").."]"..
	"list[context;outp;3,2;1,1;]"..
	"label[4,0;"..I("1. Place one sign to be\n    used as template.\n")..
			I("2. Add 'command signs' to\n    the input inventory.\n")..
			I("3. Take the copies\n    from the output inventory.").."]"..
	"list[current_player;main;0,3.5;8,4;]"..
	"listring[context;inp]"..
	"listring[current_player;main]"..
	"listring[current_player;main]"..
	"listring[context;outp]"


local function allow_metadata_inventory_put(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	if listname == "outp" then
		return 0
	end
	if minetest.get_item_group(stack:get_name(), "sign_bot_sign") ~= 1 then
		return 0
	end
	if listname == "temp" then
		return 1
	end
	return stack:get_count()
end

local function allow_metadata_inventory_take(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	return stack:get_count()
end

local function move_to_output(pos)
	local inv = M(pos):get_inventory()
	local inp_stack = inv:get_stack("inp", 1)
	local temp_stack = inv:get_stack("temp", 1)
	local outp_stack = inv:get_stack("outp", 1)
	
	if inp_stack:get_name() == "signs_bot:sign_cmnd" 
	and temp_stack:get_name() == "signs_bot:sign_cmnd"
	and outp_stack:get_name() == "" then
		local stack = ItemStack("signs_bot:sign_cmnd")
		stack:set_count(inp_stack:get_count())
		local meta = stack:get_meta()
		local temp_meta = temp_stack:get_meta()
		
		meta:set_string("cmnd", temp_meta:get_string("cmnd"))
		meta:set_string("description", temp_meta:get_string("description"))
		meta:set_string("err_msg", temp_meta:get_string("err_msg"))
		meta:set_int("err_code", temp_meta:get_int("err_code"))
		
		inp_stack:clear()
		inv:set_stack("inp", 1, inp_stack)
		inv:set_stack("outp", 1, stack)
	end
end

local function on_metadata_inventory_put(pos, listname, index, stack, player)
	if listname == "inp" then
		minetest.after(0.5, move_to_output, pos)
	end
end

minetest.register_node("signs_bot:duplicator", {
	description = I("Signs Duplicator"),
	stack_max = 1,
	tiles = {
		-- up, down, right, left, back, front
		'signs_bot_base_top.png',
		'signs_bot_base_top.png',
		'signs_bot_duplicator.png',
		'signs_bot_duplicator.png',
		'signs_bot_duplicator.png',
		'signs_bot_duplicator.png',
	},

	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		inv:set_size('inp', 1)
		inv:set_size('temp', 1)
		inv:set_size('outp', 1)
		meta:set_string("formspec", formspec)
	end,
	
	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_take = allow_metadata_inventory_take,
	on_metadata_inventory_put = on_metadata_inventory_put,
	
	can_dig = function(pos, player)
		if minetest.is_protected(pos, player:get_player_name()) then
			return false
		end
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		return inv:is_empty("inp") and inv:is_empty("temp") and inv:is_empty("outp")
	end,
	
	paramtype2 = "facedir",
	is_ground_content = false,
	groups = {cracky = 1},
	sounds = default.node_sound_metal_defaults(),
})

minetest.register_craft({
	output = "signs_bot:duplicator",
	recipe = {
		{"default:steel_ingot", "group:wood", "default:steel_ingot"},
		{"", "basic_materials:gear_steel", ""},
		{"default:tin_ingot", "", "default:tin_ingot"}
	}
})

