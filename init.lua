--[[

	Signs Bot
	=========

	Copyright (C) 2019 Joachim Stolberg

	LGPLv2.1+
	See LICENSE.txt for more information
	
	A robot controlled by signs

]]--

signs_bot = {}

local MP = minetest.get_modpath("signs_bot")
dofile(MP.."/intllib.lua")
dofile(MP.."/lib.lua")
dofile(MP.."/basis.lua")
dofile(MP.."/robot.lua")
dofile(MP.."/signs.lua")

dofile(MP.."/commands.lua")
dofile(MP.."/cmd_move.lua")
dofile(MP.."/cmd_item.lua")
dofile(MP.."/cmd_place.lua")
dofile(MP.."/cmd_sign.lua")
dofile(MP.."/cmd_pattern.lua")
dofile(MP.."/cmd_farming.lua")

dofile(MP.."/signal.lua")
dofile(MP.."/extender.lua")
dofile(MP.."/changer.lua")
dofile(MP.."/bot_flap.lua")

dofile(MP.."/duplicator.lua")
dofile(MP.."/nodes.lua")
dofile(MP.."/bot_sensor.lua")
dofile(MP.."/node_sensor.lua")
dofile(MP.."/crop_sensor.lua")
dofile(MP.."/chest.lua")

dofile(MP.."/tool.lua")
