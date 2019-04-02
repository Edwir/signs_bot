--[[

	Signs Bot
	=========

	Copyright (C) 2019 Joachim Stolberg

	LGPLv2.1+
	See LICENSE.txt for more information
	
	Signgs Changer/Control Unit for Bot Control

]]--

-- for lazy programmers
local S = function(pos) if pos then return minetest.pos_to_string(pos) end end
local P = minetest.string_to_pos
local M = minetest.get_meta

-- Load support for intllib.
local MP = minetest.get_modpath("signs_bot")
local I,_ = dofile(MP.."/intllib.lua")

local lib = signs_bot.lib

local NodeIdx = {
	["signs_bot:changer1"] = "1",
	["signs_bot:changer2"] = "2",
	["signs_bot:changer3"] = "3",
	["signs_bot:changer4"] = "4",
}

local formspec = "size[8,7]"..
	default.gui_bg..
	default.gui_bg_img..
	default.gui_slots..
	"label[1,1.3;"..I("Signs:").."]"..
	"label[2.6,0.7;1]label[5.1,0.7;2]"..
	"list[context;sign;3,0.5;2,2;]"..
	"label[2.6,1.7;3]label[5.1,1.7;4]"..
	"list[current_player;main;0,3;8,4;]"..
	"listring[context;main]"..
	"listring[current_player;main]"


-- Get one sign from the robot signs inventory
local function get_inv_sign(pos, slot)
	local inv = minetest.get_inventory({type="node", pos=pos})
	if inv then
		local stack = inv:get_stack("sign", slot)
		local taken = stack:take_item(1)
		inv:set_stack("sign", slot, stack)
		return taken
	end
end

local function put_inv_sign(pos, slot, sign)
	local inv = minetest.get_inventory({type="node", pos=pos})
	if inv then
		inv:set_stack("sign", slot, sign)
	end
end

local function signs_bot_get_signal(pos, node)
	return NodeIdx[node.name]
end

-- To be called from sensors
local function signs_bot_on_signal(pos, node, signal)
	-- swap changer
	local old_idx = NodeIdx[node.name]
	local new_idx = tonumber(signal)
	node.name = "signs_bot:changer"..signal
	if old_idx and NodeIdx[node.name] then
		local pos1 = lib.next_pos(pos, M(pos):get_int("param2"))
		minetest.swap_node(pos, node)
		-- swap sign
		local param2 = minetest.get_node(pos1).param2
		local sign = lib.dig_sign(pos1)
		if sign then
			M(pos):set_int("sign_param2_"..old_idx, param2)
			put_inv_sign(pos, old_idx, sign)
		end
		sign = get_inv_sign(pos, new_idx)
		if sign:get_count() == 1 then
			lib.place_sign(pos1, sign, M(pos):get_int("sign_param2_"..signal))
		end
	end
end

local function swap_node(pos, node)
	local slot = NodeIdx[node.name]
	if slot then
		local new_idx = (tonumber(slot) % 4) + 1
		signs_bot_on_signal(pos, node, new_idx)
	end
end

local function allow_metadata_inventory()
	return 0
end

for idx = 1,4 do
	local not_in_inv = idx == 1 and 0 or 1
	minetest.register_node("signs_bot:changer"..idx, {
		description = I("Bot Control Unit"),
		inventory_image = "signs_bot_ctrl_unit_inv.png",
		drawtype = "nodebox",
		node_box = {
			type = "fixed",
			fixed = {
				{ -11/32, -1/2, -11/32, 11/32, -5/16, 11/32},
			},
		},
		tiles = {
			-- up, down, right, left, back, front
			"signs_bot_sensor3.png^signs_bot_changer"..idx..".png",
			"signs_bot_sensor3.png",
			"signs_bot_sensor3.png^[transformFXR90",
			"signs_bot_sensor3.png^[transformFXR90",
			"signs_bot_sensor3.png^[transformFXR90",
			"signs_bot_sensor3.png^[transformFXR180",
		},
		on_construct = function(pos)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			inv:set_size('sign', 4)
		end,
		
		after_place_node = function(pos, placer)
			local meta = minetest.get_meta(pos)
			meta:set_string("formspec", formspec)
			local node = minetest.get_node(pos)
			meta:set_int("param2", (node.param2 + 2) % 4)
		end,
		
		signs_bot_get_signal = signs_bot_get_signal,
		signs_bot_on_signal = signs_bot_on_signal,
		allow_metadata_inventory_put = allow_metadata_inventory,
		allow_metadata_inventory_take = allow_metadata_inventory,
		on_punch = swap_node,

		on_rotate = screwdriver.disallow,
		paramtype = "light",
		sunlight_propagates = true,
		paramtype2 = "facedir",
		is_ground_content = false,
		groups = {cracky = 1, not_in_creative_inventory = not_in_inv},
		drop = "signs_bot:changer1",
		sounds = default.node_sound_metal_defaults(),
	})
end

minetest.register_craft({
	output = "signs_bot:changer1",
	recipe = {
		{"", "", ""},
		{"dye:yellow", "group:wood", "dye:black"},
		{"default:steel_ingot", "default:mese_crystal_fragment", "default:steel_ingot"}
	}
})
