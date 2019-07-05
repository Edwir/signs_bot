--[[

	Signs Bot
	=========

	Copyright (C) 2019 Joachim Stolberg

	LGPLv2.1+
	See LICENSE.txt for more information
	
	Bot Timer

]]--

-- for lazy programmers
local S = function(pos) if pos then return minetest.pos_to_string(pos) end end
local P = minetest.string_to_pos
local M = minetest.get_meta

-- Load support for intllib.
local MP = minetest.get_modpath("signs_bot")
local I,_ = dofile(MP.."/intllib.lua")

local CYCLE_TIME = 4

local lib = signs_bot.lib

local function update_infotext(pos, dest_pos, cmnd)
	local meta = M(pos)
	local cycle_time = meta:get_int("cycle_time")
	local text
	if cycle_time > 0 then
		text = I("Bot Timer").." ("..cycle_time.." min): "..I("Connected with")
	else
		text = I("Bot Timer").." (-- min): "..I("Connected with")
	end
	meta:set_string("infotext", text.." "..S(dest_pos).." / "..cmnd)
end	

local function update_infotext_local(pos)
	local meta = M(pos)
	local mem = tubelib2.get_mem(pos)
	local cycle_time = meta:get_int("cycle_time")
	local dest_pos = meta:get_string("signal_pos")
	local signal = meta:get_string("signal_data")
	local text1 = " (-- min): "
	local text2 = "Not connected"
	
	if dest_pos ~= "" and signal ~= "" then
		text2 = I("Connected with").." "..dest_pos.." / "..signal
	end
	if cycle_time > 0 then
		text1 = " ("..cycle_time.." min): "
	end
	if dest_pos ~= "" and signal ~= "" and cycle_time > 0 then
		mem.running = true
		minetest.get_node_timer(pos):start(CYCLE_TIME)
	end
	meta:set_string("infotext", I("Bot Timer")..text1..text2)
end	


local function formspec(meta)
	local label = minetest.formspec_escape(I("Cycle time [min]:"))
	local value = minetest.formspec_escape(meta:get_int("cycle_time"))
	return "size[4,3]"..
	default.gui_bg..
	default.gui_bg_img..
	default.gui_slots..
	"field[0.3,1;4,1;time;"..label..";"..value.."]"..
	"button_exit[1,2.2;2,1;start;"..I("Start").."]"
end

-- switch to normal texture
local function turn_off(pos)	
	local node = minetest.get_node(pos)
	node.name = "signs_bot:timer"
	minetest.swap_node(pos, node)
end

local function node_timer(pos)
	local mem = tubelib2.get_mem(pos)
	mem.time = mem.time or 0
	if mem.time > CYCLE_TIME then
		mem.time = mem.time - CYCLE_TIME
	else
		local node = minetest.get_node(pos)
		node.name = "signs_bot:timer_on"
		minetest.swap_node(pos, node)
		signs_bot.send_signal(pos)
		signs_bot.lib.activate_extender_nodes(pos, true)
		minetest.after(2, turn_off, pos)
		mem.time = M(pos):get_int("cycle_time") * 60
	end
	return mem.time > 0
end

local function on_receive_fields(pos, formname, fields, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return
	end
	if fields.key_enter_field == "time" or fields.start then
		local mem = tubelib2.get_mem(pos)
		local cycle_time = tonumber(fields.time)
		if cycle_time and cycle_time > 0 and cycle_time < 9999 then
			M(pos):set_int("cycle_time", cycle_time)
			mem.time = cycle_time * 60
		elseif cycle_time == 0 then
			minetest.get_node_timer(pos):stop()
			mem.time = 0
			M(pos):set_int("cycle_time", 0)
		end
	end
	local meta = M(pos)
	meta:set_string("formspec", formspec(meta))
	update_infotext_local(pos)
end

minetest.register_node("signs_bot:timer", {
	description = I("Bot Timer"),
	inventory_image = "signs_bot_timer_inv.png",
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{ -11/32, -1/2, -11/32, 11/32, -5/16, 11/32},
		},
	},
	tiles = {
		-- up, down, right, left, back, front
		"signs_bot_sensor2.png^signs_bot_timer.png",
		"signs_bot_sensor2.png",
	},
	
	after_place_node = function(pos, placer)
		local meta = M(pos)
		meta:set_string("infotext", "Bot Timer: Not connected")
		meta:set_string("formspec", formspec(meta))
	end,
	
	on_receive_fields = on_receive_fields,
	on_timer = node_timer,
	update_infotext = update_infotext,
	on_rotate = screwdriver.disallow,
	paramtype = "light",
	sunlight_propagates = true,
	paramtype2 = "facedir",
	is_ground_content = false,
	groups = {sign_bot_sensor = 1, cracky = 1},
	sounds = default.node_sound_metal_defaults(),
})

minetest.register_node("signs_bot:timer_on", {
	description = I("Bot Timer"),
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{ -11/32, -1/2, -11/32, 11/32, -5/16, 11/32},
		},
	},
	tiles = {
		-- up, down, right, left, back, front
		"signs_bot_sensor2.png^signs_bot_timer_on.png",
		"signs_bot_sensor2.png",
	},
			
	on_timer = node_timer,
	update_infotext = update_infotext,
	on_rotate = screwdriver.disallow,
	paramtype = "light",
	sunlight_propagates = true,
	paramtype2 = "facedir",
	is_ground_content = false,
	diggable = false,
	groups = {sign_bot_sensor = 1, not_in_creative_inventory = 1},
	sounds = default.node_sound_metal_defaults(),
})

minetest.register_craft({
	output = "signs_bot:timer",
	recipe = {
		{"", "", ""},
		{"dye:yellow", "group:stone", "dye:black"},
		{"default:steel_ingot", "default:mese_crystal_fragment", "default:steel_ingot"}
	}
})

minetest.register_lbm({
	label = "[signs_bot] Restart timer",
	name = "signs_bot:timer_restart",
	nodenames = {"signs_bot:timer", "signs_bot:timer_on"},
	run_at_every_load = true,
	action = function(pos, node)
		local mem = tubelib2.get_mem(pos)
		if mem.running then
			minetest.get_node_timer(pos):start(CYCLE_TIME)
		end
	end
})

if minetest.get_modpath("doc") then
	doc.add_entry("signs_bot", "timer", {
		name = I("Bot Timer"),
		data = {
			item = "signs_bot:timer",
			text = table.concat({
				I("Special kind of sensor."),
				I("Can be programmed with a time in seconds, e.g. to start the bot cyclically."), 
			}, "\n")		
		},
	})
end
