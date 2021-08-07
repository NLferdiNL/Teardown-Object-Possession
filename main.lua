#include "datascripts/color4.lua"
#include "scripts/utils.lua"
#include "scripts/savedata.lua"
#include "scripts/ui.lua"
#include "scripts/menu.lua"
#include "datascripts/inputList.lua"

toolName = "objectpossession"
toolReadableName = "Object Possession"

-- TODO: Make orbit camera, instead of chase.

-- For those inspecting the code,
-- I am very sorry.

local currentBody = nil
local currentLookAtBody = nil
local currentShotCooldown = 0
local maxShotCooldown = 0.5
local cameraTransform = nil

local maxPossessDistance = 15

local lastObjectCenter = nil

local cameraSpeed = 20
local minCameraDistance = 0
local currCameraDistance = 0
local maxCameraDistance = 5

local mouseXSensitivity = 10
local mouseYSensitivity = 10

local scrollSensitivity = 5

local rotationSpeed = 50
local walkRotationSpeed = 15 

local movementSpeed = 0.75

local walkMovementSpeed = 0.25

local rotationLockEnforceStrength = 0.25

local invincibilityActive = false
local walkModeActive = false
local lockedRotation = nil

function init()
	saveFileInit()
	menu_init()
	
	RegisterTool(toolName, toolReadableName, "MOD/vox/tool.vox")
	SetBool("game.tool." .. toolName .. ".enabled", true)
end

function tick(dt)
	menu_tick(dt)
	
	if not isHoldingTool() and (currentBody == nil or currentBody == 0) then
		return
	end
	
	if isMenuOpen() then
		return
	end
	
	if cooldownLogic(dt) then
		return
	end
	
	if InputPressed(binds["Toggle_Invincibility"]) then
		invincibilityActive = not invincibilityActive
	
		if invincibilityActive then
			SetTag(currentBody, "unbreakable", true)
		else
			RemoveTag(currentBody, "unbreakable")
		end
	end
	
	if currentBody == nil or currentBody == 0 then
		aimLogic()
		highlightLookAt()
		
		if isFiringTool() then
			takeOverLookAt()
		end
		
		return
	end
	
	if possessionLogic() then
		ReturnToPlayer()
	else
		movePlayerAway()
		cameraLogic(dt)
		
		if GetString("game.player.tool") ~= toolName then
			SetString("game.player.tool", toolName)
		end
	
		if InputPressed(binds["Return_To_Player"]) then
			ReturnToPlayer()
		end
		
		if InputPressed(binds["Toggle_Walk_Mode"]) then
			walkModeActive = not walkModeActive
		end
		
		if InputPressed(binds["Explosive_Power_Up"]) and not IsBodyBroken(currentBody) then
			local currVal = getExplosivePower()
			
			if currVal < 1 then
				currVal = currVal + 0.1
			elseif currVal < 4 then
				currVal = currVal + 0.25
			else
				currVal = currVal + 1
			end
			
			setExplosivePower(currVal)
		end
		
		if InputPressed(binds["Explosive_Power_Down"]) and not IsBodyBroken(currentBody)  then
			local currVal = getExplosivePower()
			
			if currVal <= 1 then
				currVal = currVal - 0.1
			elseif currVal <= 4 then
				currVal = currVal - 0.25
			else
				currVal = currVal - 1
			end
			
			setExplosivePower(currVal)
		end
		
		if InputPressed(binds["Toggle_Rotation_Lock"]) then
			if lockedRotation == nil and not (currentBody == nil and currentBody == 0) then
				local currentBodyTransform = GetBodyTransform(currentBody)
				
				SetBodyAngularVelocity(currentBody, Vec(0, 0, 0))
				
				lockedRotation = QuatCopy(currentBodyTransform.rot)
			else
				lockedRotation = nil
			end
		end
	end
end

function draw(dt)	
	menu_draw(dt)

	drawUI(dt)
end

-- UI Functions (excludes sound specific functions)

function drawUI(dt)
	if not isHoldingTool() and (currentBody == nil or currentBody == 0) then
		return
	end
	
	UiPush()
		UiAlign("left bottom")
		UiTranslate(UiWidth() * 0.01, UiHeight() * 0.99)
		UiFont("regular.ttf", 26)
		UiTextShadow(0, 0, 0, 0.5, 2.0)
		
		if currentBody ~= nil and currentBody > 0 then
			UiTranslate(30, 0)
			UiText("[" .. binds["Return_To_Player"]:upper() .. "] to return to player.")
			UiTranslate(0, -25)
			UiText("[Scroll] to zoom in and out.")
			UiTranslate(0, -25)
			UiText("[" .. binds["Rotate_Object"]:upper() .. "] to rotate the object.")
			UiTranslate(0, -25)
			UiText("[Jump / Crouch] to go up and down.")
			UiTranslate(-30, -25)
			if IsBodyBroken(currentBody) then
				UiPush()
					UiTranslate(30, 0)
					UiText("Object broken: Cannot set to explosive.")
				UiPop()
			else
				drawValue("[" .. binds["Explosive_Power_Up"]:upper() .. " / " .. binds["Explosive_Power_Down"]:upper() .. "] to change explosive power.", getExplosivePower())
			end
			UiTranslate(0, -25)
			drawToggle("[" .. binds["Toggle_Walk_Mode"]:upper() .. "] to toggle walk speed.", walkModeActive)
			UiTranslate(0, -25)
			drawToggle("[" .. binds["Toggle_Rotation_Lock"]:upper() .. "] to toggle rotation lock.", lockedRotation ~= nil)
		end
		
		UiTranslate(0, -25)
		drawToggle("[" .. binds["Toggle_Invincibility"]:upper() .. "] to toggle invincibility.", invincibilityActive)
		UiText()
	UiPop()
end

function drawToggle(label, status)
	UiPush()
		UiTranslate(0, -2.5)
		UiPush()
			if status then
				c_UiColor(Color4.Green)
			else
				c_UiColor(Color4.Red)
			end
			UiImageBox("ui/common/dot.png", 23, 23)
		UiPop()
		UiTranslate(30, 2.5)
		UiText(label)
	UiPop()
end

function drawValue(label, value)
	UiPush()
		UiFont("regular.ttf", 26)
		UiTranslate(0, -2.5)
		UiPush()
			c_UiColor(Color4.Yellow)
			local currentSize = UiGetTextSize(value)
			local fontSize = 26
			while currentSize > 30 do
				fontSize = fontSize - 0.1
				UiFont("regular.ttf", fontSize)
				currentSize = UiGetTextSize(value)
			end
			UiText(value)
		UiPop()
		UiTranslate(30, 2.5)
		UiText(label)
	UiPop()
end

function cooldownLogic(dt)
	if currentShotCooldown > 0 then
		currentShotCooldown = currentShotCooldown - dt
		return true
	end
	
	return false
end

-- Creation Functions

-- Object handlers

-- Tool Functions

function isHoldingTool()
	return GetString("game.player.tool") == toolName and GetBool("game.player.canusetool")
end

function isFiringTool()
	local isHoldingIt = isHoldingTool()
	local isFiring = InputDown("usetool")
	
	return isFiring and isHoldingIt
end

-- Particle Functions

-- Action functions

function cameraLogic(dt)
	if currentBody == nil or currentBody == 0 then
		return
	end
	
	local cameraPos = VecCopy(cameraTransform.pos)
	local currentBodyTransform = GetBodyTransform(currentBody)
	
	local objectMin, objectMax = GetBodyBounds(currentBody)
	
	local localFocusPoint = GetBodyCenterOfMass(currentBody)
	
	local objectCenter = TransformToParentPoint(currentBodyTransform, localFocusPoint)

	local objectCenterLerped = VecLerp(objectCenterRaised, lastObjectCenter, cameraSpeed * dt)
	
	local directionToBody = VecDir(cameraPos, objectCenter)
	
	local distanceToBody = VecDist(cameraPos, objectCenter)
	
	local cameraExtraLength = VecLength(VecSub(objectMax, objectMin)) / 2
	
	local xMovement = -InputValue("camerax")
	local yMovement = InputValue("cameray")
	
	if InputDown(binds["Rotate_Object"]) then
		xMovement = 0
		yMovement = 0
	end
	
	local scroll = -InputValue("mousewheel")
	
	currCameraDistance = currCameraDistance + scroll * scrollSensitivity
	
	if currCameraDistance < 0 then
		currCameraDistance = 0
	end
	
	local minHeightDiff = 0
	local maxHeightDiff = maxCameraDistance * 0.75
	
	if cameraPos[2] < objectCenter[2] - minHeightDiff then
		cameraPos[2] = objectCenter[2] - minHeightDiff
		
		if yMovement < 0 then
			yMovement = 0
		end
	elseif cameraPos[2] > objectCenter[2] + maxHeightDiff then
		cameraPos[2] = objectCenter[2] + maxHeightDiff
		
		if yMovement > 0 then
			yMovement = 0
		end
	end
	
	if xMovement ~= 0 or yMovement ~= 0 then
		local mouseMovementVec = Vec(xMovement * mouseXSensitivity, yMovement * mouseYSensitivity, 0)
		
		local worldMouseMovementVec = TransformToParentVec(cameraTransform, mouseMovementVec)
		
		cameraPos = VecAdd(cameraPos, worldMouseMovementVec)
	end
	
	 --Find voxels between camera and object and move closer to object to prevent
	 -- the object from being covered behind walls. Still kinda jittery.
	--[[QueryRejectBody(currentBody)
	
	local origin = currentBodyTransform.pos
	local direction = VecDir(origin, cameraPos)
	local maxDistance = VecDist(cameraPos, objectCenter)
	
	local hit, hitPoint = raycast(origin, direction, maxDistance, true)
	
	if hit then
		local wallOffset = VecScale(VecDir(hitPoint, origin), 2)
		cameraPos = VecAdd(hitPoint, wallOffset)
		DrawBodyOutline(currentBody, 1)
	else
		local minCamDist = minCameraDistance
		local maxCamDist = maxCameraDistance + cameraExtraLength
		
		if distanceToBody > maxCamDist  then
			cameraPos = VecAdd(cameraPos, VecScale(directionToBody, distanceToBody - maxCamDist))
		elseif distanceToBody < minCamDist then
			cameraPos = VecAdd(cameraPos, VecScale(directionToBody, distanceToBody - minCamDist))
		end
	end]]--
	
	local minCamDist = minCameraDistance + currCameraDistance
	local maxCamDist = maxCameraDistance + cameraExtraLength + currCameraDistance
	
	if distanceToBody > maxCamDist  then
		cameraPos = VecAdd(cameraPos, VecScale(directionToBody, distanceToBody - maxCamDist))
	elseif distanceToBody < minCamDist then
		cameraPos = VecAdd(cameraPos, VecScale(directionToBody, distanceToBody - minCamDist))
	end
	
	cameraPos = VecLerp(cameraTransform.pos, cameraPos, dt * cameraSpeed)
	
	local cameraRot = QuatLookAt(cameraPos, objectCenter)
	
	cameraTransform.pos = cameraPos
	cameraTransform.rot = cameraRot
	
	SetCameraTransform(cameraTransform)
	
	lastObjectCenter = objectCenter
end

function movePlayerAway()
	SetPlayerTransform(Transform(Vec(0, 1000, 0)))
end

function ReturnToPlayer()
	local currentBodyTransform = GetBodyTransform(currentBody)
	
	local origin = currentBodyTransform.pos

	local direction = VecDir(origin, cameraTransform.pos)
	
	local maxDistance =  VecDist(origin, cameraTransform.pos)
	
	QueryRejectBody(currentBody)
	
	local hit, hitPoint = raycast(origin, direction, maxDistance)
	
	if invincibilityActive then
		RemoveTag(currentBody, "unbreakable")
	end
	
	walkModeActive = false
	lockedRotation = nil
	
	if hit then
		cameraTransform.pos = hitPoint
	end
	if cameraTransform.pos[2] > 900 then
		RespawnPlayer()
	else
		SetPlayerTransform(cameraTransform)
	end
	currentBody = nil
	cameraTransform = nil
end

function takeOverLookAt()
	if currentLookAtBody == nil or currentLookAtBody == 0 then
		return
	end
	
	currentBody = currentLookAtBody
	
	if invincibilityActive then
		SetTag(currentBody, "unbreakable", true)
	end
	
	currentLookAtBody = nil
	
	cameraTransform = GetCameraTransform()
	
	local localFocusPoint = GetBodyCenterOfMass(currentBody)
	
	local objectCenter = TransformToParentPoint(currentBodyTransform, localFocusPoint)
	
	lastObjectCenter = objectCenter
	
	currCameraDistance = 0
end

function possessionLogic()
	if currentBody == nil or currentBody == 0 or GetBodyMass(currentBody) <= 0 then
		return true
	end
	
	-- Get all movement inputs
	
	local xMovement = 0
	local yMovement = 0
	local zMovement = 0
	
	local xRot = 0
	local yRot = 0
	
	if InputDown(binds["Rotate_Object"]) then
		xRot = InputValue("cameray")
		yRot = -InputValue("camerax")
	end
	
	if InputDown("up") then
		zMovement = zMovement - 1
	end
	
	if InputDown("down") then
		zMovement = zMovement + 1
	end
	
	if InputDown("left") then
		xMovement = xMovement - 1
	end
	
	if InputDown("right") then
		xMovement = xMovement + 1
	end
	
	if InputDown("jump") then
		yMovement = yMovement + 1
	end
	
	if InputDown("crouch") then
		yMovement = yMovement - 1
	end
	
	-- Get the body transform early for rotation lock
	
	local currentBodyTransform = GetBodyTransform(currentBody)
	
	-- If no input was given, no action is taken
	
	-- Having some fun, serves no purpose.
	--[[ParticleReset()
	ParticleType("smoke")
	ParticleColor(math.random(0, 10) / 10, math.random(0, 10) / 10, math.random(0, 10) / 10)
	ParticleRadius(0.1)
	ParticleEmissive(1)
	ParticleCollide(0, 1)
	SpawnParticle(currentBodyTransform.pos, Vec(0, 0, 0), 10)]]--
	
	if xRot ~=0 or yRot ~= 0 then
		local currentRotateSpeed = walkModeActive and walkRotationSpeed or rotationSpeed
		SetBodyAngularVelocity(currentBody, Vec(xRot * currentRotateSpeed, yRot * currentRotateSpeed, 0))
	end
	
	if lockedRotation ~= nil then
		--[[local cX, cY, cZ = GetQuatEuler(currentBodyTransform.rot)
		
		local tX, tY, tZ = GetQuatEuler(lockedRotation)
		
		local dX = (tX - cX) * rotationLockEnforceStrength
		local dY = (tY - cY) * rotationLockEnforceStrength
		local dZ = (tZ - cZ) * rotationLockEnforceStrength
		
		DebugWatch("curr", Vec(cX, cY, cZ))
		DebugWatch("target", Vec(tX, tY, tZ))
		DebugWatch("dest", Vec(dX, dY, dZ))]]--
		
		local rot = QuatCopy(currentBodyTransform.rot)
		
		local inverseRot = Quat(-rot[1], -rot[2], -rot[3], rot[4])
		
		local distRot = QuatRotateQuat(lockedRotation, inverseRot)
		
		local dX, dY, dZ = GetQuatEuler(distRot)
		
		SetBodyAngularVelocity(currentBody, Vec(dX, dY, dZ))
	end
	
	if xMovement == 0 and yMovement == 0 and zMovement == 0 then
		return false
	end
	
	-- Get Current movement speeds based on walk toggle
	
	local currentMovementSpeed = walkModeActive and walkMovementSpeed or movementSpeed
	
	-- Get all body related variables I need
	
	
	
	local localFocusPoint = GetBodyCenterOfMass(currentBody)
	local bodyMass = GetBodyMass(currentBody)
	
	local objectCenter = TransformToParentPoint(currentBodyTransform, localFocusPoint)
	
	-- Male a local movement vector to export from the straight looking transform.
	
	local localMovementVec = Vec(xMovement, yMovement, zMovement)
	
	-- Create a transform that is on the same level as the camera and no rotation to do
	-- camera oriented movement.
	
	local tempStraightLookPosition = VecCopy(objectCenter)
	tempStraightLookPosition[2] = cameraTransform.pos[2]
	
	local tempTransform = Transform(VecCopy(cameraTransform.pos), QuatLookAt(cameraTransform.pos, tempStraightLookPosition))
	
	-- Create the camera oriented movement vector
	
	local cameraRelatedMovement = TransformToParentPoint(tempTransform, localMovementVec)
	
	-- And turn it into a direction vector
	
	local movementDirection = VecDir(tempTransform.pos, cameraRelatedMovement)
	
	-- Scale according to speeds, and apply jump if jumping.
	
	local movementVec = VecScale(movementDirection, currentMovementSpeed * bodyMass)
	
	-- And finally apply that force
	
	ApplyBodyImpulse(currentBody, objectCenter, movementVec)
end

function getExplosivePower()
	if currentBody == nil then
		return nil
	end

	local value = GetTagValue(currentBody, "explosive")
	
	value = tonumber(value)
	
	if value == nil then
		return 0
	end
	
	return value
end

function setExplosivePower(value)
	if currentBody == nil then
		return
	end
	
	if value <= 0 then
		RemoveTag(currentBody, "explosive")
	else
		SetTag(currentBody, "explosive", value)
	end
end

function aimLogic()
	local cameraTransform = GetCameraTransform()
	
	local origin = cameraTransform.pos
	local direction = VecDir(origin, TransformToParentPoint(cameraTransform, Vec(0, 0, -1)))

	local hit, hitPoint, distance, normal, shape = raycast(origin, direction, maxPossessDistance)
	
	if hit ~= nil then
		local hitBody = GetShapeBody(shape)
		
		if IsBodyDynamic(hitBody) then
			currentLookAtBody = GetShapeBody(shape)
		else 
			currentLookAtBody = nil
		end
	else
		currentLookAtBody = nil
	end
end

function highlightLookAt()
	if currentLookAtBody == nil then
		return
	end

	DrawBodyOutline(currentLookAtBody, 1)
	DrawBodyHighlight(currentLookAtBody, 0.5)
end

-- Sprite functions

-- UI Sound Functions
