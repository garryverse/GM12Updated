// GMod 13 style context menu.

local CreateWidgets

local context_toggle = CreateClientConVar( "gm12u_contextmenu_toggle", "0", true, false )

local PANEL = {}

AccessorFunc( PANEL, "m_bHangOpen", "HangOpen" )

function PANEL:Init()

	self.Canvas = vgui.Create( "DPanelList", self )
	self.Canvas:EnableVerticalScrollbar( true )
	self.Canvas:SetSpacing( 0 )
	self.Canvas:SetPadding( 5 )
	self.Canvas:SetDrawBackground( false )

	self:SetHangOpen( false )

end

function PANEL:GetCursorAimVector()

	local x, y = gui.MousePos()

	if ( gui.ScreenToVector ) then
		return gui.ScreenToVector( x, y )
	end

	return LocalPlayer():GetCursorAimVector()

end

//
// World clicking
//
function PANEL:OnMousePressed( code )
	hook.Call( "GUIMousePressed", GAMEMODE, code, self:GetCursorAimVector() )
end

function PANEL:OnMouseReleased( code )
	hook.Call( "GUIMouseReleased", GAMEMODE, code, self:GetCursorAimVector() )
end

function PANEL:OnMouseDoublePressed( code )
	hook.Call( "GUIMouseDoublePressed", GAMEMODE, code, self:GetCursorAimVector() )
end

//
// Hover box around the entity under the cursor. Cursor enter/exit fires when
// moving onto/off child panels too, so the box hides over the tool panel.
//
function PANEL:OnCursorEntered()
	self.m_bCursorOver = true
end

function PANEL:OnCursorExited()
	self.m_bCursorOver = false
end

function PANEL:Paint()
	if ( !self.m_bCursorOver ) then return end
	if ( !properties || !properties.DrawHoverBox ) then return end

	properties.DrawHoverBox( self:GetCursorAimVector() )
end

function PANEL:Open()

	self:SetHangOpen( false )

	// If the spawn menu is open, try to close it..
	if ( ValidPanel( g_SpawnMenu ) && g_SpawnMenu:IsVisible() ) then
		g_SpawnMenu:Close( true )
	end

	if ( self:IsVisible() ) then return end

	CloseDermaMenus()

	// Built on the first open, so widgets added by addons that load afterwards still show up
	if ( !ValidPanel( self.DesktopWidgets ) ) then CreateWidgets( self ) end

	self:MakePopup()
	self:SetVisible( true )
	self:SetKeyboardInputEnabled( false )
	self:SetMouseInputEnabled( true )

	RestoreCursorPosition()

	local bShouldShow = hook.Call( "ContextMenuShowTool", GAMEMODE )
	local bShow = bShouldShow == nil || bShouldShow

	// Set up the active tool's control panel.
	if ( bShow && ValidPanel( g_ActiveControlPanel ) ) then
		self.OldParent = g_ActiveControlPanel:GetParent()
		self.OldPosX, self.OldPosY = g_ActiveControlPanel:GetPos()

		g_ActiveControlPanel:SetParent( self )

		self.Canvas:Clear()
		self.Canvas:AddItem( g_ActiveControlPanel )
		self.Canvas:Rebuild()
		self.Canvas:SetVisible( true )
	else
		self.Canvas:SetVisible( false )
	end

	self:InvalidateLayout( true )
end

function PANEL:Close()
	if ( self:GetHangOpen() ) then
		self:SetHangOpen( false )
		return
	end

	RememberCursorPosition()

	CloseDermaMenus()

	self:SetKeyboardInputEnabled( false )
	self:SetMouseInputEnabled( false )

	self:SetAlpha( 255 )
	self:SetVisible( false )
	self:RestoreControlPanel()
end

function PANEL:PerformLayout()
	self:SetPos( 0, 0 )
	self:SetSize( ScrW(), ScrH() )

	if ( ValidPanel( g_ActiveControlPanel ) && self.Canvas:IsVisible() ) then
		g_ActiveControlPanel:InvalidateLayout( true )

		local Tall = math.min( g_ActiveControlPanel:GetTall() + 10, ScrH() * 0.8 )
		self.Canvas:SetSize( 320, Tall )
		self.Canvas:SetPos( ScrW() - self.Canvas:GetWide() - 50, ScrH() - 50 - Tall )
		self.Canvas:InvalidateLayout( true )
	end

	if ( ValidPanel( self.DesktopWidgets ) ) then
		self.DesktopWidgets:SetPos( 0, 0 )
		self.DesktopWidgets:SetTall( ScrH() )
	end
end

function PANEL:StartKeyFocus( pPanel )
	self:SetKeyboardInputEnabled( true )
	self:SetHangOpen( true )
end

function PANEL:EndKeyFocus( pPanel )
	self:SetKeyboardInputEnabled( false )
end

function PANEL:RestoreControlPanel()
	// Restore the active panel
	if ( !ValidPanel( g_ActiveControlPanel ) ) then return end
	if ( !self.OldParent ) then return end

	g_ActiveControlPanel:SetParent( self.OldParent )
	g_ActiveControlPanel:SetPos( self.OldPosX, self.OldPosY )

	self.OldParent = nil

end

vgui.Register( "GM12U_ContextMenu", PANEL, "EditablePanel" )


//
// Desktop widget column, filled from list.Get( "DesktopWindows" )
//
// list.Set( "DesktopWindows", "MyWidget", {
//     title     = "My Widget",
//     icon      = "gui/silkicons/wrench",                // a material, OR..
//     model     = "models/props_c17/oildrum001.mdl",     // ..a model, drawn as a spawnicon
//     width     = 400,
//     height    = 300,
//     onewindow = true,                                  // only allow one window open at once
//     init      = function( icon, window ) end
// } )
//
local ICON_W, ICON_H = 80, 82

local function CreateWidgetIcon( parent, k, wdgt )
	local icon = vgui.Create( "DButton", parent )
	icon:SetText( "" )
	icon:SetSize( ICON_W, ICON_H )
	icon.Paint = function() end
	icon.WidgetClass = k

	if ( wdgt.model ) then
		local spawnicon = vgui.Create( "SpawnIcon", icon )
		spawnicon:SetModel( wdgt.model )
		spawnicon:SetSize( 64, 64 )
		spawnicon:SetPos( 8, 0 )
		spawnicon:SetMouseInputEnabled( false )
	elseif ( wdgt.icon ) then
		local image = vgui.Create( "DImage", icon )
		image:SetImage( wdgt.icon )
		image:SetSize( 64, 64 )
		image:SetPos( 8, 0 )
		image:SetMouseInputEnabled( false )
	end

	local label = vgui.Create( "DLabel", icon )
	label:SetText( wdgt.title or k )
	label:SetTextColor( color_white )
	label:SizeToContents()
	label:SetPos( ( ICON_W - label:GetWide() ) * 0.5, 66 )
	label:SetMouseInputEnabled( false )
	if ( label.SetExpensiveShadow ) then label:SetExpensiveShadow( 1, Color( 0, 0, 0, 200 ) ) end

	icon.DoClick = function()
		// The widget may have changed with lua_refresh, so we grab it again
		local newWdgt = list.Get( "DesktopWindows" )[ k ]
		if ( !newWdgt ) then return end

		if ( newWdgt.onewindow && ValidPanel( icon.Window ) ) then
			icon.Window:Center()
			return
		end

		icon.Window = vgui.Create( "DFrame", g_ContextMenu )
		icon.Window:SetSize( newWdgt.width or 400, newWdgt.height or 300 )
		icon.Window:SetTitle( newWdgt.title or k )
		icon.Window:Center()

		newWdgt.init( icon, icon.Window )
	end

	return icon
end

function CreateWidgets( menu )
	local column = vgui.Create( "Panel", menu )
	column:SetWide( ICON_W + 16 )
	column:SetMouseInputEnabled( true )

	// Clicks between the icons still count as world clicks
	column.OnMousePressed = function( s, code ) menu:OnMousePressed( code ) end
	column.OnMouseReleased = function( s, code ) menu:OnMouseReleased( code ) end

	local y = 8
	for k, wdgt in SortedPairs( list.Get( "DesktopWindows" ) ) do
		local icon = CreateWidgetIcon( column, k, wdgt )
		icon:SetPos( 8, y )
		y = y + ICON_H + 8
	end

	menu.DesktopWidgets = column
end


//
// A replacement for the sandbox gamemode's CreateContextMenu()
//
local function CreateContextMenu()
	local enabled = hook.Call( "ContextMenuEnabled", GAMEMODE )
	if ( enabled == false ) then return end

	if ( ValidPanel( g_ContextMenu ) ) then
		g_ContextMenu:Remove()
	end

	g_ContextMenu = nil

	g_ContextMenu = vgui.Create( "GM12U_ContextMenu" )
	if ( !ValidPanel( g_ContextMenu ) ) then return end

	g_ContextMenu:SetVisible( false )

	hook.Call( "ContextMenuCreated", GAMEMODE, g_ContextMenu )
end

local contextMenuLastOpen = 0

local function OnContextMenuOpen( self )
	// Already open (toggle)
	if ( context_toggle:GetBool() && ValidPanel( g_ContextMenu ) && g_ContextMenu:IsVisible() ) then return end
	contextMenuLastOpen = SysTime()

	// Let the gamemode decide whether we should open it or not.
	if ( !hook.Call( "ContextMenuOpen", GAMEMODE ) ) then return end

	if ( ValidPanel( g_ContextMenu ) && !g_ContextMenu:IsVisible() ) then
		g_ContextMenu:Open()
	end

	hook.Call( "ContextMenuOpened", GAMEMODE )
end

local function OnContextMenuClose( self )
	if ( context_toggle:GetBool() && SysTime() - contextMenuLastOpen < 0.180 ) then return end

	if ( ValidPanel( g_ContextMenu ) ) then g_ContextMenu:Close() end
	hook.Call( "ContextMenuClosed", GAMEMODE )
end


// The Sandbox gamemode defines its own CreateContextMenu/OnContextMenuOpen when
// the gamemode loads, so we swap ours in afterwards.
// We only replace functions that came from sandbox's spawnmenu/contextmenu.lua,
// so a gamemode with its own context menu is left alone.
local function FuncSource( func )
	if ( type( func ) != "function" ) then return nil end
	if ( !debug || !debug.getinfo ) then return nil end

	local info = debug.getinfo( func, "S" )
	if ( !info || !info.source ) then return nil end

	// Windows builds can report the path with backslashes
	return string.gsub( info.source:lower(), "\\", "/" )
end

local function IsSandboxContextFunc( func )
	if ( type( func ) != "function" ) then return false end

	local source = FuncSource( func )

	// No debug library to check with, so go by whether sandbox's context menu was loaded
	if ( !source ) then return type( _G.CreateContextMenu ) == "function" end

	return string.find( source, "contextmenu.lua", 1, true ) != nil
end

local Installed = false

local function Install()
	if ( Installed ) then return end
	if ( !GAMEMODE ) then return end
	if ( !IsSandboxContextFunc( GAMEMODE.OnContextMenuOpen ) ) then return end

	GAMEMODE.OnContextMenuOpen = OnContextMenuOpen

	if ( IsSandboxContextFunc( GAMEMODE.OnContextMenuClose ) ) then
		GAMEMODE.OnContextMenuClose = OnContextMenuClose
	end

	_G.CreateContextMenu = CreateContextMenu

	Installed = true

	// If the Sandbox gamemode already built its context menu, replace it now
	if ( g_ContextMenu ) then CreateContextMenu() end
end

hook.Add( "OnGamemodeLoaded", "GM12U_ContextMenu", Install )
hook.Add( "Initialize", "GM12U_ContextMenu", Install )
hook.Add( "InitPostEntity", "GM12U_ContextMenu", Install )
Install()

concommand.Add( "gm12u_contextmenu_reload", function()
	if ( Installed ) then CreateContextMenu() end
end )
