#include "scripts/utils.lua"

binds = {
	Return_To_Player = "r",
	Toggle_Invincibility = "c",
	Toggle_Walk_Mode = "shift",
	Toggle_Rotation_Lock = "z",
	Rotate_Object = "rmb",
	Explosive_Power_Up = "t",
	Explosive_Power_Down = "g",
	Toggle_Void_Mode = "n",
	Open_Menu = "m", -- Only one that can't be changed!
}

controllerBinds = {
	Return_To_Player = "interact",
	Toggle_Invincibility = "extra3",
	Toggle_Walk_Mode = "extra2",
	Toggle_Rotation_Lock = "usetool",
	Rotate_Object = "grab",
	Explosive_Power_Up = "extra0",
	Explosive_Power_Down = "extra1",
	Toggle_Void_Mode = "n",
	Open_Menu = "m", -- Won't even support this on controller. Menu only used to enable an old broken feature anyway.
}

local bindBackup = deepcopy(binds)

local bindOrder = {
	"Return_To_Player",
	"Toggle_Invincibility",
	"Toggle_Walk_Mode",
	"Toggle_Rotation_Lock",
	"Rotate_Left",
	"Rotate_Right",
	"Toggle_Void_Mode",
}
		
local bindNames = {
	Return_To_Player = "Return To Player",
	Toggle_Invincibility = "Toggle Invincibility",
	Toggle_Walk_Mode = "Toggle Walk Mode",
	Toggle_Rotation_Lock = "Toggle Rotation Lock",
	Rotate_Left = "Rotate Left",
	Rotate_Right = "Rotate Right",
	Toggle_Void_Mode = "Toggle Void Mode",
	Open_Menu = "Open Menu",
}
function resetKeybinds()
	binds = deepcopy(bindBackup)
end

function getFromBackup(id)
	return bindBackup[id]
end

function GetInputMethod()
	if LastInputDevice() == 2 then
		return "GAMEPAD"
	elseif LastInputDevice() == 1 then
		return "MNK"
	else
		return "UNKNOWN"
	end
end

function GetBindButton(id)
	if binds[id] == nil then
		return "UNKNOWN"
	end
	
	if GetInputMethod() == "GAMEPAD" then
		return controllerBinds[id]
	else
		return binds[id]
	end
end

function GetBindName(id)
	if binds[id] == nil then
		return "UNKNOWN"
	end
	
	return bindNames[id]
end

function GetInputPressed(id)
	if binds[id] == nil then
		return "UNKNOWN"
	end
	
	if GetInputMethod() == "GAMEPAD" then
		return InputPressed(controllerBinds[id])
	else
		return InputPressed(binds[id])
	end
end

function GetInputReleased(id)
	if binds[id] == nil then
		return "UNKNOWN"
	end
	
	if GetInputMethod() == "GAMEPAD" then
		return InputReleased(controllerBinds[id])
	else
		return InputReleased(binds[id])
	end
end

function GetInputDown(id)
	if binds[id] == nil then
		return "UNKNOWN"
	end
	
	if GetInputMethod() == "GAMEPAD" then
		return InputDown(controllerBinds[id])
	else
		return InputDown(binds[id])
	end
end