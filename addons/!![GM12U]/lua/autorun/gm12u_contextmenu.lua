local Dir = "gm12u_contextmenu/"

if ( SERVER ) then
	AddCSLuaFile( "autorun/gm12u_contextmenu.lua" )
	AddCSLuaFile( Dir .. "sh_properties.lua" )
	AddCSLuaFile( Dir .. "sh_properties_default.lua" )
	AddCSLuaFile( Dir .. "cl_contextmenu.lua" )
	AddCSLuaFile( Dir .. "cl_widgets.lua" )
end

include( Dir .. "sh_properties.lua" )
include( Dir .. "sh_properties_default.lua" )

if ( CLIENT ) then
	include( Dir .. "cl_contextmenu.lua" )
	include( Dir .. "cl_widgets.lua" )
end
