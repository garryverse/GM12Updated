// Default desktop widgets for the context menu.

// Player Model - a version of 13's playermodel editor.
// Uses the same list and convar as the Options > Player Model menu.
list.Set( "DesktopWindows", "PlayerEditor", {
	title		= "Player Model",
	model		= "models/player/kleiner.mdl",
	width		= 430,
	height		= 420,
	onewindow	= true,
	init		= function( icon, window )
		local grid = vgui.Create( "DPanelList", window )
		grid:SetPos( 5, 28 )
		grid:SetSize( window:GetWide() - 10, window:GetTall() - 58 )
		grid:EnableHorizontal( true )
		grid:EnableVerticalScrollbar( true )
		grid:SetSpacing( 2 )
		grid:SetPadding( 4 )

		for name, model in SortedPairs( list.Get( "PlayerOptionsModel" ) ) do
			local spawnicon = vgui.Create( "SpawnIcon" )
			spawnicon:SetModel( model )
			spawnicon:SetSize( 64, 64 )
			spawnicon:SetTooltip( name )
			spawnicon.DoClick = function()
				RunConsoleCommand( "cl_playermodel", name )
				surface.PlaySound( "ui/buttonclickrelease.wav" )
			end

			grid:AddItem( spawnicon )
		end

		local hint = vgui.Create( "DLabel", window )
		hint:SetPos( 8, window:GetTall() - 24 )
		hint:SetText( "Changes apply when you respawn." )
		hint:SizeToContents()
	end
} )
