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

local lastObjectCenter = nil

local cameraSpeed = 20
local minCameraDistance = 0 --5
local maxCameraDistance = 5 --7

local mouseXSensitivity = 0.1
local mouseYSensitivity = 0.1

local movementSpeed = 0.75
local jumpStrength = 5

function init()
	saveFileInit()
	menu_init()
	
	RegisterTool(toolName, toolReadableName, "MOD/vox/tool.vox")
	SetBool("game.tool." .. toolName .. ".enabled", true)
end

function tick(dt)
	menu_tick(dt)
	
	if not isHoldingTool() and currentBody == nil then
		return
	end
	
	if isMenuOpen() then
		return
	end
	
	if cooldownLogic(dt) then
		return
	end
	
	if currentBody ~= nil then
		if possessionLogic() then
			ReturnToPlayer()
		else
			movePlayerAway()
			cameraLogic(dt)
		
			if InputPressed("r") then
				ReturnToPlayer()
			end
		end
		
		return
	end
	
	aimLogic()
	highlightLookAt()
	
	if isFiringTool() then
		takeOverLookAt()
	end
end

function draw(dt)	
	menu_draw(dt)

	drawUI(dt)
end

-- UI Functions (excludes sound specific functions)

function drawUI(dt)
	if not isHoldingTool() then
		return
	end
	
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
	
	local objectCenter = TransformToParentPoint(currentBodyTransform, localFocusPoint) --VecLerp(objectMin, objectMax, 0.5)
	
	--local objectCenterRaised = VecAdd(Vec(0, 1, 0), objectCenter)
	
	local objectCenterLerped = VecLerp(objectCenterRaised, lastObjectCenter, cameraSpeed * dt)
	
	local directionToBody = VecDir(cameraPos, objectCenter)
	
	local distanceToBody = VecDist(cameraPos, objectCenter)
	
	local cameraExtraLength = VecLength(VecSub(objectMax, objectMin))
	
	--[[local currCamDist = currCameraDistance + cameraExtraLength
	
	if distanceToBody > currCamDist  then
		cameraPos = VecAdd(cameraPos, VecScale(directionToBody, distanceToBody - currCamDist))
	elseif distanceToBody < currCamDist then
		cameraPos = VecAdd(cameraPos, VecScale(directionToBody, distanceToBody - currCamDist))
	end]]--
	
	--cameraPos = VecAdd(cameraPos, VecScale(directionToBody, cameraExtraLength))
	
	local xMovement = -InputValue("mousedx")
	local yMovement = InputValue("mousedy")
	
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
	
	local minCamDist = minCameraDistance
	local maxCamDist = maxCameraDistance + cameraExtraLength
	
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
	
	currentLookAtBody = nil
	
	cameraTransform = GetCameraTransform()
	
	--local objectMin, objectMax = GetBodyBounds(currentBody)
	
	local localFocusPoint = GetBodyCenterOfMass(currentBody)
	
	local objectCenter = TransformToParentPoint(currentBodyTransform, localFocusPoint) -- VecLerp(objectMin, objectMax, 0.5)
	
	lastObjectCenter = objectCenter
end

function possessionLogic()
	if currentBody == nil or currentBody == 0 or GetBodyMass(currentBody) <= 0 then
		return true
	end
	
	local xMovement = 0
	local yMovement = 0
	local zMovement = 0
	
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
	
	if InputPressed("jump") then
		yMovement = yMovement + 1
	end
	
	if xMovement == 0 and yMovement == 0 and zMovement == 0 then
		return false
	end
	
	local localMovementVec = Vec(xMovement, 0, zMovement)
	
	local currentBodyTransform = GetBodyTransform(currentBody)
	
	local localFocusPoint = GetBodyCenterOfMass(currentBody)
	
	local objectCenter = TransformToParentPoint(currentBodyTransform, localFocusPoint)
	
	local tempLookAt = VecCopy(objectCenter) --VecCopy(currentBodyTransform.pos)
	tempLookAt[2] = cameraTransform.pos[2]
	local tempTransform = Transform(cameraTransform.pos, QuatLookAt(cameraTransform.pos, tempLookAt))
	
	local cameraRelatedMovement = TransformToParentPoint(tempTransform, localMovementVec)
	
	local direction = VecDir(cameraTransform.pos, cameraRelatedMovement)
	
	local bodyMass = GetBodyMass(currentBody)
	
	local movementVec = VecScale(direction, movementSpeed * bodyMass)
	
	movementVec = VecAdd(movementVec, Vec(0, yMovement * jumpStrength * bodyMass, 0))
	
	local objectMin, objectMax = GetBodyBounds(currentBody)
	local objectCenter = VecLerp(objectMin, objectMax, 0.5)
	
	ApplyBodyImpulse(currentBody, objectCenter, movementVec)
end

function aimLogic()
	local cameraTransform = GetCameraTransform()
	
	local origin = cameraTransform.pos
	local direction = VecDir(origin, TransformToParentPoint(cameraTransform, Vec(0, 0, -1)))
	
	local maxDistance = 10
	
	--QueryRequire("physical dynamic")
	local hit, hitPoint, distance, normal, shape = raycast(origin, direction, maxDistance)
	
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
