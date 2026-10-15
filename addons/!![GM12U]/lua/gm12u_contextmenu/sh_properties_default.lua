
// Default properties, based on the ones 13 ships with. Mostly.

// Physics props/ragdolls only. 12 has no clientside physics objects for
// props, so we check the movetype instead.
// (doors and other brush ents use MOVETYPE_PUSH and are skipped).
// The server also makes sure there's actually a physics object.

local function HasPhysics( ent )
	if ( ent:GetMoveType() != MOVETYPE_VPHYSICS ) then return false end
	if ( SERVER ) then return ent:GetPhysicsObjectCount() > 0 end
	return true
end

// Remove (same as the remover tool's left click)
properties.Add( "remove", {
	MenuLabel = "Remove",
	Order = 1000,
	PrependSpacer = true,

	Receive = function( self, ply, ent )
		constraint.RemoveAll( ent )

		timer.Simple( 1, function() if ( ValidEntity( ent ) ) then ent:Remove() end end )

		ent:SetNotSolid( true )
		ent:SetMoveType( MOVETYPE_NONE )
		ent:SetNoDraw( true )

		local ed = EffectData()
			ed:SetEntity( ent )
		util.Effect( "entity_remove", ed, true, true )
	end
} )

// Ignite / Extinguish
// IsOnFire isn't very reliable in 12, so we network our own flag.
local function IsBurning( ent )
	return ent:GetNetworkedBool( "GM12U_OnFire", false )
end

properties.Add( "ignite", {
	MenuLabel = "Ignite",
	Order = 900,

	Filter = function( self, ent ) return !IsBurning( ent ) && !ent:IsWorld() && !ent:IsNPC() end,

	Receive = function( self, ply, ent )
		ent:Ignite( 360, 0 )
		ent:SetNetworkedBool( "GM12U_OnFire", true )
		timer.Simple( 360, function() if ( ValidEntity( ent ) ) then ent:SetNetworkedBool( "GM12U_OnFire", false ) end end )
	end
} )

properties.Add( "extinguish", {
	MenuLabel = "Extinguish",
	Order = 900,

	Filter = function( self, ent ) return IsBurning( ent ) end,

	Receive = function( self, ply, ent )
		ent:Extinguish()
		ent:SetNetworkedBool( "GM12U_OnFire", false )
	end
} )

// Collisions
properties.Add( "collision_off", {
	MenuLabel = "Disable Collisions",
	Order = 1500,
	PrependSpacer = true,

	Filter = function( self, ent ) return HasPhysics( ent ) && !ent:GetNetworkedBool( "GM12U_NoCollide", false ) end,

	Receive = function( self, ply, ent )
		ent:SetCollisionGroup( COLLISION_GROUP_WORLD )
		ent:SetNetworkedBool( "GM12U_NoCollide", true )
	end
} )

properties.Add( "collision_on", {
	MenuLabel = "Enable Collisions",
	Order = 1500,
	PrependSpacer = true,

	Filter = function( self, ent ) return HasPhysics( ent ) && ent:GetNetworkedBool( "GM12U_NoCollide", false ) end,

	Receive = function( self, ply, ent )
		ent:SetCollisionGroup( COLLISION_GROUP_NONE )
		ent:SetNetworkedBool( "GM12U_NoCollide", false )
	end
} )

// Gravity
local function SetGravity( ent, enabled )
	for i = 0, ent:GetPhysicsObjectCount() - 1 do
		local phys = ent:GetPhysicsObjectNum( i )
		if ( phys && phys:IsValid() ) then
			phys:EnableGravity( enabled )
			phys:Wake()
		end
	end

	ent:SetNetworkedBool( "GM12U_NoGravity", !enabled )
end

properties.Add( "gravity_off", {
	MenuLabel = "Disable Gravity",
	Order = 1501,

	Filter = function( self, ent ) return HasPhysics( ent ) && !ent:GetNetworkedBool( "GM12U_NoGravity", false ) end,
	Receive = function( self, ply, ent ) SetGravity( ent, false ) end
} )

properties.Add( "gravity_on", {
	MenuLabel = "Enable Gravity",
	Order = 1501,

	Filter = function( self, ent ) return HasPhysics( ent ) && ent:GetNetworkedBool( "GM12U_NoGravity", false ) end,
	Receive = function( self, ply, ent ) SetGravity( ent, true ) end
} )

//
// Keep Upright (same constraint the Keep Upright tool uses)
//
properties.Add( "keepupright", {
	MenuLabel = "Keep Upright",
	Order = 1502,

	Filter = function( self, ent )
		return ent:GetClass() == "prop_physics" && !ent:GetNetworkedBool( "GM12U_Upright", false )
	end,

	Receive = function( self, ply, ent )
		local phys = ent:GetPhysicsObject()
		if ( !phys || !phys:IsValid() ) then return end

		local constr = constraint.Keepupright( ent, phys:GetAngle(), 0, 999999 )
		if ( constr ) then
			ent:SetNetworkedBool( "GM12U_Upright", true )
			constr:CallOnRemove( "GM12U_Upright", function()
				if ( ValidEntity( ent ) ) then ent:SetNetworkedBool( "GM12U_Upright", false ) end
			end )
		end
	end
} )

properties.Add( "keepupright_stop", {
	MenuLabel = "Stop Keeping Upright",
	Order = 1502,

	Filter = function( self, ent ) return ent:GetNetworkedBool( "GM12U_Upright", false ) end,

	Receive = function( self, ply, ent )
		constraint.RemoveConstraints( ent, "Keepupright" )
		ent:SetNetworkedBool( "GM12U_Upright", false )
	end
} )

// Skin
properties.Add( "skin", {
	MenuLabel = "Skin",
	Order = 601,

	Filter = function( self, ent )
		if ( !ent.SkinCount ) then return false end
		return ( ent:SkinCount() or 0 ) > 1
	end,

	SubMenu = function( self, submenu, ent )
		for i = 0, ent:SkinCount() - 1 do
			local label = "Skin " .. i
			if ( ent:GetSkin() == i ) then label = label .. " (current)" end
			submenu:AddOption( label, function() if ( ValidEntity( ent ) ) then self:SendToServer( ent, i ) end end )
		end
	end,

	Receive = function( self, ply, ent, data )
		local skin = tonumber( data )
		if ( !skin || skin < 0 || skin >= ent:SkinCount() ) then return end
		ent:SetSkin( math.floor( skin ) )
	end
} )

// Bodygroups
properties.Add( "bodygroups", {
	MenuLabel = "Bodygroups",
	Order = 600,

	Filter = function( self, ent )
		if ( !ent.GetNumBodyGroups || !ent.GetBodygroupCount ) then return false end
		for i = 0, ent:GetNumBodyGroups() - 1 do
			if ( ent:GetBodygroupCount( i ) > 1 ) then return true end
		end
		return false
	end,

	SubMenu = function( self, submenu, ent )
		for i = 0, ent:GetNumBodyGroups() - 1 do
			local count = ent:GetBodygroupCount( i )
			if ( count > 1 ) then
				local name = ent.GetBodygroupName && ent:GetBodygroupName( i ) or ( "Group " .. i )
				local groupmenu = submenu:AddSubMenu( name )
				for j = 0, count - 1 do
					local label = tostring( j )
					if ( ent:GetBodygroup( i ) == j ) then label = label .. " (current)" end
					groupmenu:AddOption( label, function() if ( ValidEntity( ent ) ) then self:SendToServer( ent, i .. ":" .. j ) end end )
				end
			end
		end
	end,

	Receive = function( self, ply, ent, data )
		local group, value = string.match( data, "^(%d+):(%d+)$" )
		group, value = tonumber( group ), tonumber( value )
		if ( !group || !value ) then return end
		if ( group >= ent:GetNumBodyGroups() || value >= ent:GetBodygroupCount( group ) ) then return end
		ent:SetBodygroup( group, value )
	end
} )

// Doors (This is NOT in 13)
// We can't read a door's locked state, so both options are always shown.
local DoorClasses = {
	prop_door_rotating = true,
	func_door = true,
	func_door_rotating = true
}

local function IsDoor( ent )
	return DoorClasses[ ent:GetClass() ] == true
end

properties.Add( "door_unlock", {
	MenuLabel = "Unlock Door",
	Order = 700,

	Filter = function( self, ent ) return IsDoor( ent ) end,
	Receive = function( self, ply, ent ) ent:Fire( "Unlock", "", 0 ) end

} )

properties.Add( "door_lock", {
	MenuLabel = "Lock Door",
	Order = 701,

	Filter = function( self, ent ) return IsDoor( ent ) end,
	Receive = function( self, ply, ent ) ent:Fire( "Lock", "", 0 ) end
} )
