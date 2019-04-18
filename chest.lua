--[[

	Signs Bot
	=========

	Copyright (C) 2019 Joachim Stolberg

	LGPLv2.1+
	See LICENSE.txt for more information
	
	Signs Bot Chest

]]--

-- for lazy programmers
local S = function(pos) if pos then return minetest.pos_to_string(pos) end end
local P = minetest.string_to_pos
local M = minetest.get_meta

-- Load support for intllib.
local MP = minetest.get_modpath("signs_bot")
local I,_ = dofile(MP.."/intllib.lua")

local NODE_IO = minetest.global_exists("node_io")

local function get_inv_state(pos)
	local inv = minetest.get_inventory({type="node", pos=pos})
	if not inv then return "almost full" end
    if inv:is_empty("main") then
        return "empty"
    else
        local list = inv:get_list("main")
        for _, item in ipairs(list) do
            if item:is_empty() then
                return "not empty"
            end
        end
    end
    return "almost full"
end

local function check_state(pos)
	local state = M(pos):get_string("state")
	if state == get_inv_state(pos) then
		signs_bot.send_signal(pos)
		signs_bot.lib.activate_extender_nodes(pos, true)
	end
end

local function update_infotext(pos, dest_pos, cmnd)
	local meta = M(pos)
	local state = get_inv_state(pos)
	meta:set_string("infotext", I("Bot Chest: Sends signal to ")..S(dest_pos).." / "..cmnd..", if "..state)
	meta:set_string("state", state)
	
end	

local function formspec()
	return "size[9,8]"..
	default.gui_bg..
	default.gui_bg_img..
	default.gui_slots..
	"list[context;main;0.5,0;8,4;]"..
	"list[current_player;main;0.5,4.3;8,4;]"..
	"listring[context;main]"..
	"listring[current_player;main]"
end

if NODE_IO then
	minetest.register_node("signs_bot:chest", {
		description = I("Signs Bot Chest"),
		tiles = {
			-- up, down, right, left, back, front
			'signs_bot_chest_top.png',
			'signs_bot_chest_top.png',
			'signs_bot_chest_side.png',
			'signs_bot_chest_side.png',
			'signs_bot_chest_side.png',
			'signs_bot_chest_front.png',
		},

		on_construct = function(pos)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			inv:set_size('main', 32)
		end,
		
		after_place_node = function(pos, placer)
			local mem = tubelib2.init_mem(pos)
			mem.running = false
			local meta = minetest.get_meta(pos)
			meta:set_string("owner", placer:get_player_name())
			meta:set_string("formspec", formspec(pos, mem))
			meta:set_string("infotext", "Bot Chest: Not connected")
		end,

		allow_metadata_inventory_put = function(pos, listname, index, stack, player)
			if minetest.is_protected(pos, player:get_player_name()) then
				return 0
			end
			return stack:get_count()
		end,
		allow_metadata_inventory_take = function(pos, listname, index, stack, player)
			if minetest.is_protected(pos, player:get_player_name()) then
				return 0
			end
			return stack:get_count()
		end,
		on_metadata_inventory_move = function(pos, from_list, from_index, to_list)
			check_state(pos)
		end,
		on_metadata_inventory_put = function(pos, listname)
			check_state(pos)
		end,
		on_metadata_inventory_take = function(pos, listname)
			check_state(pos)
		end,

		node_io_can_put_item = function(pos, node, side) return true end,
		node_io_room_for_item = function(pos, node, side, itemstack, count)
			local inv = minetest.get_meta(pos):get_inventory()
			if not inv then return 0 end
			return node_io.room_for_item_in_inventory(inv, "main", itemstack, count)
		end,
		node_io_put_item = function(pos, node, side, putter, itemstack)
			local owner = M(pos):get_string("owner")
			if owner == putter:get_player_name() then
				local left_over = node_io.put_item_in_inventory(pos, node, "main", putter, itemstack)
				check_state(pos)
				return left_over
			end
		end,
		node_io_can_take_item = function(pos, node, side) return true end,
		node_io_get_item_size = function(pos, node, side)
			return node_io.get_inventory_size(pos, "main")
		end,
		node_io_get_item_name = function(pos, node, side, index)
			return node_io.get_inventory_name(pos, "main", index)
		end,
		node_io_get_item_stack = function(pos, node, side, index)
			return node_io.get_inventory_stack(pos, "main", index)
		end,
		node_io_take_item = function(pos, node, side, taker, want_item, want_count)
			local owner = M(pos):get_string("owner")
			if owner == taker:get_player_name() then
				local left_over = node_io.take_item_from_inventory(pos, node, "main", taker, want_item, want_count)
				check_state(pos)
				return left_over
			end
		end,
		
		update_infotext = update_infotext,
		on_rotate = screwdriver.disallow,
		paramtype2 = "facedir",
		is_ground_content = false,
		groups = {cracky = 1, sign_bot_sensor = 1},
		sounds = default.node_sound_metal_defaults(),
	})
else
	minetest.register_node("signs_bot:chest", {
		description = I("Signs Bot Chest"),
		tiles = {
			-- up, down, right, left, back, front
			'signs_bot_chest_top.png',
			'signs_bot_chest_top.png',
			'signs_bot_chest_side.png',
			'signs_bot_chest_side.png',
			'signs_bot_chest_side.png',
			'signs_bot_chest_front.png',
		},

		on_construct = function(pos)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			inv:set_size('main', 32)
		end,
		
		after_place_node = function(pos, placer)
			local mem = tubelib2.init_mem(pos)
			mem.running = false
			local meta = minetest.get_meta(pos)
			meta:set_string("owner", placer:get_player_name())
			meta:set_string("formspec", formspec(pos, mem))
			meta:set_string("infotext", "Bot Chest: Not connected")
		end,

		allow_metadata_inventory_put = function(pos, listname, index, stack, player)
			if minetest.is_protected(pos, player:get_player_name()) then
				return 0
			end
			return stack:get_count()
		end,
		allow_metadata_inventory_take = function(pos, listname, index, stack, player)
			if minetest.is_protected(pos, player:get_player_name()) then
				return 0
			end
			return stack:get_count()
		end,
		on_metadata_inventory_move = function(pos, from_list, from_index, to_list)
			check_state(pos)
		end,
		on_metadata_inventory_put = function(pos, listname)
			check_state(pos)
		end,
		on_metadata_inventory_take = function(pos, listname)
			check_state(pos)
		end,

		update_infotext = update_infotext,
		on_rotate = screwdriver.disallow,
		paramtype2 = "facedir",
		is_ground_content = false,
		groups = {cracky = 1, sign_bot_sensor = 1},
		sounds = default.node_sound_metal_defaults(),
	})
end	

signs_bot.register_inventory({"signs_bot:chest"}, {
	put = {
		allow_inventory_put = function(pos, stack, player_name)
			local owner = M(pos):get_string("owner")
			minetest.after(1, check_state, pos)
			return owner == player_name
		end, 
		listname = "main",
	},
	take = {
		allow_inventory_take = function(pos, stack, player_name)
			local owner = M(pos):get_string("owner")
			minetest.after(1, check_state, pos)
			return owner == player_name
		end, 
		listname = "main",
	},
})
