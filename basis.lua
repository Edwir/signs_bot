--[[

	Signs Bot
	=========

	Copyright (C) 2019 Joachim Stolberg

	GPL v3
	See LICENSE.txt for more information
	
	Signs Bot: Robot basis block

]]--

-- for lazy programmers
local S = function(pos) if pos then return minetest.pos_to_string(pos) end end
local P = minetest.string_to_pos
local M = minetest.get_meta

-- Load support for intllib.
local MP = minetest.get_modpath("signs_bot")
local I,_ = dofile(MP.."/intllib.lua")

local lib = signs_bot.lib

local CYCLE_TIME = 1
signs_bot.MAX_CAPA = 600

local function formspec(pos, mem)
	mem.running = mem.running or false
	local cmnd = mem.running and "stop;"..I("Off") or "start;"..I("On") 
	local bot = not mem.running and "image[0.6,1;1,1;signs_bot_bot_inv.png]" or ""
	local current_capa = mem.capa or (signs_bot.MAX_CAPA * 0.9)
	return "size[9,7.6]"..
	default.gui_bg..
	default.gui_bg_img..
	default.gui_slots..
	"label[2.1,0;"..I("Signs").."]label[5.3,0;"..I("Other items").."]"..
	"image[0.6,1;1,1;signs_bot_form_mask.png]"..
	bot..
	signs_bot.formspec_battery_capa(signs_bot.MAX_CAPA, current_capa)..
	"label[2.1,0.5;1]label[3.1,0.5;2]label[4.1,0.5;3]"..
	"list[context;sign;1.8,1;3,2;]"..
	"label[2.1,3;4]label[3.1,3;5]label[4.1,3;6]"..
	"label[5.3,0.5;1]label[6.3,0.5;2]label[7.3,0.5;3]label[8.3,0.5;4]"..
	"list[context;main;5,1;4,2;]"..
	"label[5.3,3;5]label[6.3,3;6]label[7.3,3;7]label[8.3,3;8]"..
	"button[0.2,2;1.5,1;"..cmnd.."]"..
	"list[current_player;main;0.5,3.8;8,4;]"..
	"listring[context;main]"..
	"listring[current_player;main]"
end

function signs_bot.infotext(pos, state)
	local meta = M(pos)
	local number = meta:get_string("number")
	state = state or "<unknown>"
	meta:set_string("infotext", I("Robot Box ")..number..": "..state)
end

local function reset_robot(pos, mem)
	mem.robot_param2 = (minetest.get_node(pos).param2 + 1) % 4
	mem.robot_pos = lib.next_pos(pos, mem.robot_param2, 1)
	mem.steps = nil
	local pos_below = {x=mem.robot_pos.x, y=mem.robot_pos.y-1, z=mem.robot_pos.z}
	signs_bot.place_robot(mem.robot_pos, pos_below, mem.robot_param2)	
end

local function start_robot(base_pos)
	local mem = tubelib2.get_mem(base_pos)
	local meta = M(base_pos)
	mem.lCmnd1 = {}
	mem.lCmnd2 = {}
	mem.running = true
	mem.charging = false
	mem.error = false
	mem.stored_node = nil
	if minetest.global_exists("techage") then
		mem.capa = mem.capa or 0 -- enable power consumption
	else
		mem.capa = nil
	end
	meta:set_string("formspec", formspec(base_pos, mem))
	signs_bot.infotext(base_pos, I("running"))
	reset_robot(base_pos, mem)
	minetest.get_node_timer(base_pos):start(CYCLE_TIME)
	return true
end

function signs_bot.stop_robot(base_pos, mem)
	local meta = M(base_pos)
	if mem.signal_request ~= true then
		mem.running = false
		if minetest.global_exists("techage") then
			minetest.get_node_timer(base_pos):start(2)
			mem.charging = true
		else
			minetest.get_node_timer(base_pos):stop()
			mem.charging = false
		end
		signs_bot.infotext(base_pos, I("stopped"))
		meta:set_string("formspec", formspec(base_pos, mem))
		signs_bot.remove_robot(mem)
	else
		mem.signal_request = false
		start_robot(base_pos)
	end
end

-- Used by the pairing tool
local function signs_bot_get_signal(pos, node)
	local mem = tubelib2.get_mem(pos)
	if mem.running then
		return "on"
	else
		return "off"
	end
end

-- To be called from sensors
local function signs_bot_on_signal(pos, node, signal)
	local mem = tubelib2.get_mem(pos)
	if signal == "on" and not mem.running then
		start_robot(pos)
	elseif signal == "off" and mem.running then
		signs_bot.stop_robot(pos, mem)
--	else
--		mem.signal_request = (signal == "on")
	end
end


local function node_timer(pos, elapsed)
	local mem = tubelib2.get_mem(pos)
	if mem.charging and signs_bot.while_charging then
		return signs_bot.while_charging(pos, mem)
	else
		local res = false
		--local t = minetest.get_us_time()
		if mem.running then
			res = signs_bot.run_next_command(pos, mem)
		end
		--t = minetest.get_us_time() - t
		--print("node_timer", t)
		return res and mem.running
	end
end

local function on_receive_fields(pos, formname, fields, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return
	end
	local mem = tubelib2.get_mem(pos)
	local meta = minetest.get_meta(pos)
	
	if fields.update then
		meta:set_string("formspec", formspec(pos, mem))
	elseif fields.start then
		start_robot(pos)
	elseif fields.stop then
		signs_bot.stop_robot(pos, mem)
	end
end

local function on_rightclick(pos)
	local mem = tubelib2.get_mem(pos)
	M(pos):set_string("formspec", formspec(pos, mem))
end

local function allow_metadata_inventory_put(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	local mem = tubelib2.get_mem(pos)
	if mem.running then
		return 0
	end
	local name = stack:get_name()
	if listname == "sign" and minetest.get_item_group(name, "sign_bot_sign") ~= 1 then
		return 0
	end
	return stack:get_count()
end

local function allow_metadata_inventory_take(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	local mem = tubelib2.get_mem(pos)
	if mem.running then
		return 0
	end
	return stack:get_count()
end

local function allow_metadata_inventory_move(pos, from_list, from_index, to_list, to_index, count, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	local mem = tubelib2.get_mem(pos)
	if mem.running then
		return 0
	end
	if from_list ~= to_list then
		return 0
	end
	return count
end	

minetest.register_node("signs_bot:box", {
	description = I("Signs Bot Box"),
	stack_max = 1,
	tiles = {
		-- up, down, right, left, back, front
		'signs_bot_base_top.png',
		'signs_bot_base_top.png',
		'signs_bot_base_right.png',
		'signs_bot_base_left.png',
		'signs_bot_base_front.png',
		'signs_bot_base_front.png',
	},

	on_construct = function(pos)
		local meta = M(pos)
		local inv = meta:get_inventory()
		inv:set_size('main', 8)
		inv:set_size('sign', 6)
	end,
	
	after_place_node = function(pos, placer)
		local mem = tubelib2.init_mem(pos)
		mem.running = false
		mem.error = false
		local meta = M(pos)
		local number = ""
		if minetest.global_exists("techage") then
			number = techage.add_node(pos, "signs_bot:box")
		end
		meta:set_string("owner", placer:get_player_name())
		meta:set_string("number", number)
		meta:set_string("formspec", formspec(pos, mem))
		meta:set_string("signs_bot_cmnd", "turn_off")
		meta:set_int("err_code", 0)
		signs_bot.infotext(pos, I("stopped"))
	end,

	signs_bot_get_signal = signs_bot_get_signal,
	signs_bot_on_signal = signs_bot_on_signal,
	on_receive_fields = on_receive_fields,
	on_rightclick = on_rightclick,
	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_take = allow_metadata_inventory_take,
	allow_metadata_inventory_move = allow_metadata_inventory_move,
	
	can_dig = function(pos, player)
		if minetest.is_protected(pos, player:get_player_name()) then
			return
		end
		local mem = tubelib2.get_mem(pos)
		if mem.running then
			return
		end
		local inv = M(pos):get_inventory()
		return inv:is_empty("main") and inv:is_empty("sign")
	end,
	
	on_dig = function(pos, node, puncher, pointed_thing)
		minetest.node_dig(pos, node, puncher, pointed_thing)
	end,
	
	on_timer = node_timer,
	
	on_rotate = screwdriver.disallow,
	paramtype2 = "facedir",
	is_ground_content = false,
	groups = {cracky = 1},
	sounds = default.node_sound_metal_defaults(),
})


if minetest.global_exists("techage") then
	minetest.register_craft({
		output = "signs_bot:box",
		recipe = {
			{"default:steel_ingot", "group:wood", "default:steel_ingot"},
			{"basic_materials:motor", "techage:ta4_wlanchip", "basic_materials:gear_steel"},
			{"default:tin_ingot", "", "default:tin_ingot"}
		}
	})
else
	minetest.register_craft({
		output = "signs_bot:box",
		recipe = {
			{"default:steel_ingot", "group:wood", "default:steel_ingot"},
			{"basic_materials:motor", "default:mese_crystal", "basic_materials:gear_steel"},
			{"default:tin_ingot", "", "default:tin_ingot"}
		}
	})
end

if minetest.global_exists("techage") then
	techage.register_node({"signs_bot:box"}, {
		on_pull_item = function(pos, in_dir, num)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			return techage.get_items(inv, "main", num)
		end,
		on_push_item = function(pos, in_dir, stack)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			return techage.put_items(inv, "main", stack)
		end,
		on_unpull_item = function(pos, in_dir, stack)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			return techage.put_items(inv, "main", stack)
		end,
		
		on_recv_message = function(pos, topic, payload)
			local mem = tubelib2.get_mem(pos)
			if topic == "state" then
				if mem.error then
					return "fault"
				elseif mem.running then
					if mem.curr_cmnd == "stop" then
						return "standby"
					elseif mem.blocked then
						return "blocked"
					else
						return "running"
					end
				elseif mem.capa then
					if mem.capa <= 0 then
						return "nopower"
					elseif mem.capa >= signs_bot.MAX_CAPA then
						return "stopped"
					else
						return "loading"
					end
				else
					return "stopped"
				end
			elseif topic == "fuel" then
				return signs_bot.percent_value(signs_bot.MAX_CAPA, mem.capa)
			else
				return "unsupported"
			end
		end,
	})	
	
end

if minetest.get_modpath("doc") then
	doc.add_entry("signs_bot", "box", {
		name = I("Signs Bot Box"),
		data = {
			item = "signs_bot:box",
			text = table.concat({
				I("The Box is the housing of the bot."),
				I("Place the box and start the bot by means of the 'On' button."), 
				I("If the mod techage is installed, the bot needs electrical power."),
				"",
				I("The bot leaves the box on the right side."),
				I("It will not start, if this position is blocked."),
				"",
				I("To stop and remove the bot, press the 'Off' button."),
				"",
				I("The box inventory simulates the inventory of the bot."),
				I("You will not be able to access the inventory, if the bot is running."),
				I("The bot can carry up to 8 stacks and 6 signs with it."),
			}, "\n")		
		},
	})
end
