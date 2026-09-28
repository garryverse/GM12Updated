local USE_EYE_ANGLES = true
local CENTER_ON_OBB  = true

hook.Add( "Initialize", "PropCenterFix_Override", function()

	-- Bails out if the current gamemode doesn't use the sandbox spawn function.
	if ( !DoPlayerEntitySpawn ) then return end

	function DoPlayerEntitySpawn( player, entity_name, model, iSkin )

		local vStart = player:GetShootPos()
		local vForward = player:GetAimVector()

		local trace = {}
		trace.start = vStart
		trace.endpos = vStart + ( vForward * 2048 )
		trace.filter = player

		local tr = util.TraceLine( trace )

		local ent = ents.Create( entity_name )
		if ( !ent:IsValid() ) then return end

		local ang = player:EyeAngles()
		ang.yaw = ang.yaw + 180
		ang.roll = 0
		ang.pitch = 0

		if ( entity_name == "prop_ragdoll" ) then
			ang.pitch = -90
		end

		ent:SetModel( model )
		ent:SetSkin( iSkin )
		ent:SetAngles( ang )
		ent:SetPos( tr.HitPos )
		ent:Spawn()
		ent:Activate()

		local vFlushPoint

		if ( CENTER_ON_OBB ) then
			-- Puts the bounding box center on the hit point, nudged off of the surface.
			local center = ent:LocalToWorld( ent:OBBCenter() )
			vFlushPoint = tr.HitPos + ( ent:GetPos() - center ) + ( tr.HitNormal * ( ent:OBBMaxs() - ent:OBBMins() ):Length() * 0.5 )
		else
			-- Original behaviour
			vFlushPoint = tr.HitPos - ( tr.HitNormal * 512 )
			vFlushPoint = ent:NearestPoint( vFlushPoint )
			vFlushPoint = ent:GetPos() - vFlushPoint
			vFlushPoint = tr.HitPos + vFlushPoint
		end

		if ( entity_name != "prop_ragdoll" ) then

			ent:SetPos( vFlushPoint )
			player:SendLua( "achievements.SpawnedProp()" )

		else

			local VecOffset = vFlushPoint - ent:GetPos()
			for i = 0, ent:GetPhysicsObjectCount() - 1 do
				local phys = ent:GetPhysicsObjectNum( i )
				phys:SetPos( phys:GetPos() + VecOffset )
			end

			player:SendLua( "achievements.SpawnedRagdoll()" )

		end

		return ent
	end

	-- Spawn command wrapper
	local PLAYER = FindMetaTable( "Player" )

	local function WithEyeTrace( fn )
		return function( ply, ... )

			local oldAim   = PLAYER.GetAimVector
			local oldTrace = PLAYER.GetEyeTraceNoCursor

			PLAYER.GetAimVector = function( self )
				return self:EyeAngles():Forward()
			end

			PLAYER.GetEyeTraceNoCursor = function( self )
				local start = self:GetShootPos()
				return util.TraceLine( {
					start  = start,
					endpos = start + self:EyeAngles():Forward() * 16384,
					filter = self
				} )
			end

			local results = { pcall( fn, ply, ... ) }

			-- Restore the original tracer, even if the handler errors out.
			PLAYER.GetAimVector = oldAim
			PLAYER.GetEyeTraceNoCursor = oldTrace

			if ( !results[1] ) then ErrorNoHalt( tostring( results[2] ) .. "\n" ) return end

			return unpack( results, 2 )
		end
	end

	DoPlayerEntitySpawn = WithEyeTrace( DoPlayerEntitySpawn )
	if ( CCSpawnNPC )     then concommand.Add( "gmod_spawnnpc",    WithEyeTrace( CCSpawnNPC ) ) end
	if ( CCSpawnSENT )    then concommand.Add( "gm_spawnsent",     WithEyeTrace( CCSpawnSENT ) ) end
	if ( CCSpawnSWEP )    then concommand.Add( "gm_spawnswep",     WithEyeTrace( CCSpawnSWEP ) ) end
	if ( CCSpawnVehicle ) then concommand.Add( "gm_spawnvehicle",  WithEyeTrace( CCSpawnVehicle ) ) end
end)
