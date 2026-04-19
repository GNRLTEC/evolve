--[[-------------------------------------------------------------------------
    Clientside autorun file
---------------------------------------------------------------------------]]

-- Set up evolve table
evolve = {}

-- Load clientside files
include("ev_framework.lua")
include("ev_theme/sh_theme.lua")       -- must come before anything that draws
include("ev_menu/cl_menu.lua")
include("ev_cl_init.lua")
