#include "datascripts/inputList.lua"
#include "datascripts/color4.lua"
#include "scripts/ui.lua"
#include "scripts/textbox.lua"
#include "scripts/utils.lua"
#include "datascripts/keybinds.lua"

local menuOpened = false
local menuOpenLastFrame = false

local rebinding = nil

local erasingBinds = 0

local menuWidth = 0.3
local menuHeight = 0.4

function menu_init()
	
end

function menu_tick(dt)
	if GetInputPressed("Open_Menu") and GetString("game.player.tool") == toolName and menuEnabled then
		menuOpened = not menuOpened
		
		if not menuOpened then
			menuCloseActions()
		end
	end
	
	if menuOpened and not menuOpenLastFrame then
		menuUpdateActions()
		menuOpenActions()
	end
	
	menuOpenLastFrame = menuOpened
	
	if rebinding ~= nil then
		local lastKeyPressed = getKeyPressed()
		
		if lastKeyPressed ~= nil then
			binds[rebinding] = lastKeyPressed
			rebinding = nil
		end
	end
	
	textboxClass_tick()
	
	if erasingBinds > 0 then
		erasingBinds = erasingBinds - dt
	end
	
	if isMenuOpen() then
	
	end
end

function setupTextBoxes()
	--[[local textBox01, newBox01 = textboxClass_getTextBox(1)

	if newBox01 then
		textBox01.name = "Spread"
		textBox01.value = spread .. ""
		textBox01.numbersOnly = true
		textBox01.limitsActive = true
		textBox01.numberMin = 0
		textBox01.numberMax = 5
		
		spreadTextBox = textBox01
	end]]--
end

function centralMenu()
	UiPush()
		UiBlur(0.75)
		
		UiAlign("center middle")
		UiTranslate(UiWidth() * 0.5, UiHeight() * 0.5)
		
		UiPush()
			UiColorFilter(0, 0, 0, 0.25)
			UiImageBox("MOD/sprites/square.png", UiWidth() * menuWidth, UiHeight() * menuHeight, 10, 10)
		UiPop()
		
		UiWordWrap(UiWidth() * menuWidth)
		
		UiTranslate(0, -UiHeight() * (menuHeight / 2))
		
		UiFont("bold.ttf", 45)
		
		UiTranslate(0, 40)
		
		UiText(toolReadableName .. " Settings")
		
		UiFont("regular.ttf", 26)
		
		setupTextBoxes()
		
		UiButtonImageBox("MOD/sprites/square.png", 0, 0, 0, 0, 0, 0.5)
		
		UiPush()
			UiTranslate(0, UiHeight() * menuHeight * 0.2)
			
			--[[if erasingBinds > 0 then
				UiPush()
				c_UiColor(Color4.Red)
				if UiTextButton("Are you sure?" , 400, 40) then
					binds = deepcopy(bindBackup)
					erasingBinds = 0
				end
				UiPop()
			else
				if UiTextButton("Reset binds to defaults" , 400, 40) then
					erasingBinds = 5
				end
			end
			
			UiTranslate(0, 50)]]--
			
			local voidButtonText = "Disabled"
			
			if voidModeAvailable then
				voidButtonText = "Enabled"
			end
			
			if UiTextButton("Enable Void Mode: " .. voidButtonText , 400, 40) then
				voidModeAvailable = not voidModeAvailable
			end
			
			UiTranslate(0, UiHeight() * menuHeight * 0.2)
			UiText("Warning: Void mode is very unpolished and was\nonly ever tested on keyboard.\n\nMay not work with controller.")
			
			--drawToggle("Enable Void Mode: ", voidModeAvailable, function(i) voidModeAvailable = i end)
			
		UiPop()
		UiPush()
			UiTranslate(0, UiHeight() * menuHeight * 0.75)
			
			if UiTextButton("Close", 400, 40) then
				menuCloseActions()
			end
		UiPop()
	UiPop()
end


function menu_draw(dt)
	if not isMenuOpen() then
		return
	end
	
	UiMakeInteractive()
	
	centralMenu()
end

function drawRebindable(id, key)
	UiPush()
		UiButtonImageBox("MOD/sprites/square.png", 0, 0, 0, 0, 0, 0.5)
	
		UiTranslate(UiWidth() * menuWidth / 1.5, 0)
	
		UiAlign("right middle")
		UiText(bindNames[id] .. "")
		
		UiTranslate(UiWidth() * menuWidth * 0.1, 0)
		
		UiAlign("left middle")
		
		if rebinding == id then
			c_UiColor(Color4.Green)
		else
			c_UiColor(Color4.Yellow)
		end
		
		if UiTextButton(key, 40, 40) then
			rebinding = id
		end
	UiPop()
end

function menuOpenActions()
	
end

function menuUpdateActions()
	--[[if spreadTextBox ~= nil then
		spreadTextBox.value =  spread .. ""
	end]]--
end

function menuCloseActions()
	menuOpened = false
	rebinding = nil
	saveToFile();
	--spread = tonumber(spreadTextBox.value)
end

function isMenuOpen()
	return menuOpened
end

function setMenuOpen(val)
	menuOpened = val
end