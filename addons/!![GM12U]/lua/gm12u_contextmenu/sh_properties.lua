// Properties library - a take on 13's properties module.

// Right clicking an entity while the context menu is open shows every
// property whose Filter returns true for that entity.

// !! EXAMPLE !! //
// properties.Add( "name", {
//     MenuLabel     = "Do Thing",           // text in the menu
//     Order         = 100,                  // lower = higher up
//     PrependSpacer = false,                // spacer above this option
//     Filter        = function( self, ent, ply ) return true end,   // shared
//     Action        = function( self, ent, tr ) self:SendToServer( ent ) end, // client (optional, this is the default)
//     SubMenu       = function( self, submenu, ent, tr ) end,        // client (optional, makes this a submenu)
//     Receive       = function( self, ply, ent, data ) end           // server, data is the optional string from SendToServer
// } )

// A server re-runs the Filter and properties.CanBeTargeted before Receive.

properties = properties or {}
properties.List = properties.List or {}

local COMMAND = "gm12u_property"

local META = {}
META.__index = META

function META:Filter( ent, ply ) return true end

function META:Action( ent, tr )
	self:SendToServer( ent )
end

function META:Receive( ply, ent, data ) end

if ( CLIENT ) then
	function META:SendToServer( ent, data )
		RunConsoleCommand( COMMAND, self.InternalName, ent:EntIndex(), tostring( data or "" ) )
	end
end

function properties.Add( name, tab )
	name = name:lower()

	tab.InternalName = name
	tab.Order = tab.Order or 0
	properties.List[ name ] = setmetatable( tab, META )
end

function properties.Get( name )
	return properties.List[ name:lower() ]
end

// Checks whether this player do property stuff to an entity at all
function properties.CanBeTargeted( ent, ply )
	if ( !ValidEntity( ent ) ) then return false end
	if ( ent:IsPlayer() ) then return false end
	if ( ent:IsWeapon() && ValidEntity( ent:GetOwner() ) ) then return false end

	return true
end

// Server side permission check. Gamemodes/addons can hook CanProperty,
// otherwise we ask CanTool (with the property name as the tool mode) so
// existing prop protection addons are respected.
local function CanUseProperty( ply, name, ent )
	local ret = hook.Call( "CanProperty", GAMEMODE, ply, name, ent )
	if ( ret != nil ) then return ret end

	local tr = { Entity = ent, HitPos = ent:GetPos(), HitNonWorld = true, HitWorld = false, Hit = true }
	ret = hook.Call( "CanTool", GAMEMODE, ply, tr, name )
	if ( ret != nil ) then return ret end

	return true

end

if ( SERVER ) then
	concommand.Add( COMMAND, function( ply, cmd, args )

		if ( !ValidEntity( ply ) ) then return end

		local prop = properties.List[ tostring( args[1] or "" ):lower() ]
		if ( !prop ) then return end

		local ent = Entity( tonumber( args[2] ) or -1 )
		if ( !properties.CanBeTargeted( ent, ply ) ) then return end
		if ( !prop:Filter( ent, ply ) ) then return end
		if ( !CanUseProperty( ply, prop.InternalName, ent ) ) then return end

		prop:Receive( ply, ent, args[3] or "" )
	end )

	return
end

//
// Everything below is clientside
//

local function SortedProperties()
	local tab = {}
	for k, v in pairs( properties.List ) do table.insert( tab, v ) end
	table.sort( tab, function( a, b )
		if ( a.Order == b.Order ) then return a.InternalName < b.InternalName end
		return a.Order < b.Order
	end )

	return tab
end

function properties.GetHovered( eyepos, eyevec )
	local tr = util.TraceLine( {
		start = eyepos,
		endpos = eyepos + eyevec * 4096,
		filter = LocalPlayer()
	} )

	if ( !properties.CanBeTargeted( tr.Entity, LocalPlayer() ) ) then return nil, tr end

	return tr.Entity, tr
end

function properties.OpenEntityMenu( ent, tr )
	local menu = DermaMenu()
	local count = 0

	for _, prop in ipairs( SortedProperties() ) do
		if ( prop:Filter( ent, LocalPlayer() ) ) then

			if ( prop.PrependSpacer && count > 0 ) then menu:AddSpacer() end

			if ( prop.SubMenu ) then
				local submenu = menu:AddSubMenu( prop.MenuLabel )
				prop:SubMenu( submenu, ent, tr )
			else
				menu:AddOption( prop.MenuLabel, function()
					if ( ValidEntity( ent ) ) then prop:Action( ent, tr ) end
				end )
			end

			count = count + 1
		end
	end

	if ( count == 0 ) then
		menu:Remove()
		return false
	end

	menu:Open()
	return true
end

// Right clicking in the context menu opens the property menu
hook.Add( "GUIMousePressed", "GM12U_PropertiesClick", function( code, vector )
	if ( code != MOUSE_RIGHT ) then return end
	if ( !ValidPanel( g_ContextMenu ) || !g_ContextMenu:IsVisible() ) then return end
	if ( !vector ) then return end

	local ent, tr = properties.GetHovered( LocalPlayer():EyePos(), vector )
	if ( !ent ) then return end

	// Returning true stops the base gamemode from sending this click to the server as well
	if ( properties.OpenEntityMenu( ent, tr ) ) then return true end
end )

//
// 13 draws a halo around whatever you're hovering, but 12 has no halo
// library so we draw a box around it instead.
local function BoxCorners( ent )
	local mins, maxs = ent:OBBMins(), ent:OBBMaxs()

	return {
		Vector( mins.x, mins.y, mins.z ), Vector( maxs.x, mins.y, mins.z ),
		Vector( mins.x, maxs.y, mins.z ), Vector( maxs.x, maxs.y, mins.z ),
		Vector( mins.x, mins.y, maxs.z ), Vector( maxs.x, mins.y, maxs.z ),
		Vector( mins.x, maxs.y, maxs.z ), Vector( maxs.x, maxs.y, maxs.z )
	}
end

//
// Called from the context menu's Paint, which covers the whole screen at 0,0
// so screen coordinates line up.
//
function properties.DrawHoverBox( aimvec )
	local ent = properties.GetHovered( LocalPlayer():EyePos(), aimvec )
	if ( !ent ) then return end

	local x1, y1, x2, y2 = ScrW(), ScrH(), 0, 0
	for _, corner in ipairs( BoxCorners( ent ) ) do
		local scr = ent:LocalToWorld( corner ):ToScreen()
		// GM12's ToScreen might not set .visible at all, so only bail on an explicit false
		if ( scr.visible == false ) then return end
		x1 = math.min( x1, scr.x ) y1 = math.min( y1, scr.y )
		x2 = math.max( x2, scr.x ) y2 = math.max( y2, scr.y )
	end

	surface.SetDrawColor( 255, 255, 255, 200 )
	surface.DrawOutlinedRect( x1, y1, x2 - x1, y2 - y1 )
	surface.SetDrawColor( 0, 0, 0, 100 )
	surface.DrawOutlinedRect( x1 - 1, y1 - 1, x2 - x1 + 2, y2 - y1 + 2 )
end
