#include "datascripts/color4.lua"
#include "scripts/utils.lua"
#include "scripts/savedata.lua"
#include "scripts/ui.lua"
#include "scripts/menu.lua"
#include "datascripts/inputList.lua"
#include "datascripts/keybinds.lua"

toolName = "objectpossession"
toolReadableName = "Object Possession"

-- TODO: Make orbit camera, instead of chase.

-- For those inspecting the code,
-- I am very sorry.

menuEnabled = true

debugEnabled = false
local debugStarted = false

local currentBody = nil
local currentLookAtBody = nil
local maxShotCooldown = 0.5
local cameraTransform = nil

local maxPossessDistance = 15

local cameraSpeed = 20
local minCameraDistance = 0
local currCameraDistance = 0
local maxCameraDistance = 5

local minHeightDiff = 0
local maxHeightDiff = maxCameraDistance * 0.75

local mouseXSensitivity = 20
local mouseYSensitivity = 20

local scrollSensitivity = 5

local rotationSpeed = 50
local walkRotationSpeed = 15 

local movementSpeed = 0.75

local walkMovementSpeed = 0.25

local invincibilityActive = false
local walkModeActive = false
local lockedRotation = nil

voidModeAvailable = false
local voidModeActive = false
local voidMovementSpeed = 10
local voidStartRange = 10
local voidStartStrength = 80
local voidRange = 0
local voidStrength = 0
local voidStrengthPerMassGained = 0.15
local voidPos = nil

local playerStartTransform = nil

local voidBodies = {}

local controllerCrouchDown = false

local explosiveBodyClass = {
	active = false,
	mass = nil,
	power = 0,
}

local explosiveBodies = {}

function init()
	saveFileInit()
	menu_init()
	
	RegisterTool(toolName, toolReadableName, "MOD/vox/tool.vox")
	SetBool("game.tool." .. toolName .. ".enabled", true)
end

function tick(dt)
	if not debugStarted and debugEnabled then
		debugStarted = true
		SetString("game.player.tool", toolName)
	end
		
	menu_tick(dt)
	handleExplosiveBodies()
	
	if not isHoldingTool() and (currentBody == nil or currentBody == 0) and not voidModeActive then
		return
	end
	
	if isMenuOpen() then
		return
	end
	
	if GetInputPressed("Toggle_Void_Mode") and (currentBody == nil or currentBody == 0) and voidModeAvailable then
		voidModeActive = not voidModeActive
		
		if voidModeActive then
			cameraTransform = TransformCopy(GetCameraTransform())
			playerStartTransform = TransformCopy(GetPlayerTransform())
			
			minCameraDistance = 5
		
			voidStrength = voidStartStrength
			voidRange = voidStartRange
			voidPos = VecCopy(cameraTransform.pos)
			
			--minHeightDiff = maxCameraDistance
			--maxHeightDiff = maxCameraDistance
			voidBodies = {}
		else
			--minHeightDiff = 0
			--maxHeightDiff = maxCameraDistance * 0.75
			SetPlayerTransform(playerStartTransform)
		end
	end
	
	if voidModeActive then
		voidLogic(dt)
		cameraLogic(dt, voidPos, voidRange)
		forceToolHeld()
		movePlayerAway()
		
		if minCameraDistance > 0 then
			minCameraDistance = 0
		end
		return
	end
	
	if GetInputPressed("Toggle_Invincibility") then
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
		forceToolHeld()
		movePlayerAway()
		lookAtObject(dt)
	
		if GetInputPressed("Return_To_Player") then
			ReturnToPlayer()
		end
		
		if GetInputPressed("Toggle_Walk_Mode") then
			walkModeActive = not walkModeActive
		end
		
		if GetInputPressed("Explosive_Power_Up")then
			local currVal = getExplosivePower(currentBody)
			
			if currVal < 0.5 then
				currVal = 0.5
			else
				currVal = currVal + 0.1
			end
			
			if currVal > 4 then
				currVal = 4
			end
			
			editExplosiveBody(currentBody, currVal)
		end
		
		if GetInputPressed("Explosive_Power_Down") then
			local currVal = getExplosivePower(currentBody)
			
			if currVal <= 0.5 then
				currVal = 0
			else
				currVal = currVal - 0.1
			end
			
			if currVal < 0 then
				currVal = 0
			end
			
			editExplosiveBody(currentBody, currVal)
		end
		
		if GetInputPressed("Toggle_Rotation_Lock") then
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
			UiText("[" .. GetBindButton("Return_To_Player"):upper() .. "] to return to player.")
			UiTranslate(0, -25)
			if GetInputMethod() == "MNK" then
				UiText("[Scroll] to zoom in and out.")
			else
				UiText("[Switch tools] to zoom in and out.")
			end
			UiTranslate(0, -25)
			UiText("[" .. GetBindButton("Rotate_Object"):upper() .. "] to rotate the object.")
			UiTranslate(0, -25)
			UiText("[Jump / Crouch] to go up and down.")
			UiTranslate(-30, -25)
			drawValue("[" .. GetBindButton("Explosive_Power_Up"):upper() .. " / " .. GetBindButton("Explosive_Power_Down"):upper() .. "] to change explosive power.", getExplosivePower(currentBody))
			UiTranslate(0, -25)
			drawToggle("[" .. GetBindButton("Toggle_Walk_Mode"):upper() .. "] to toggle walk speed.", walkModeActive)
			UiTranslate(0, -25)
			drawToggle("[" .. GetBindButton("Toggle_Rotation_Lock"):upper() .. "] to toggle rotation lock.", lockedRotation ~= nil)
		end
		
		UiTranslate(0, -25)
		drawToggle("[" .. GetBindButton("Toggle_Invincibility"):upper() .. "] to toggle invincibility.", invincibilityActive)
		if ((currentBody == nil or currentBody == 0) and voidModeAvailable) then
			UiTranslate(30, -25)
			if voidModeActive then
				UiText("[" .. GetBindButton("Toggle_Void_Mode"):upper() .. "] to return to player.")
			else
				UiText("[" .. GetBindButton("Toggle_Void_Mode"):upper() .. "] to enter the Void mode.")
			end
		end
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
			local fontSize = getMaxTextSize(value, 26, 30)
			UiFont("regular.ttf", fontSize)
			UiText(value)
		UiPop()
		UiTranslate(30, 2.5)
		UiText(label)
	UiPop()
end

-- Creation Functions

function editExplosiveBody(bodyId, power)
	if bodyId == nil then
		return
	end
	
	if explosiveBodies[bodyId] ~= nil then
		explosiveBodies[bodyId].power = power
		return
	end
	
	local newExplosiveBody = deepcopy(explosiveBodyClass)
	
	newExplosiveBody.power = power
	newExplosiveBody.mass = GetBodyMass(bodyId)
	
	explosiveBodies[bodyId] = newExplosiveBody
end

-- Object handlers

function handleExplosiveBodies()
	for bodyId, settings in pairs(explosiveBodies) do
		local bodyMass = GetBodyMass(bodyId)
		
		if bodyMass ~= settings.mass then
			local currentBodyTransform = GetBodyTransform(bodyId)
			local localExplosionPos = GetBodyCenterOfMass(bodyId)
			local explosionPos = TransformToParentPoint(currentBodyTransform, localExplosionPos)
			Explosion(explosionPos, settings.power)
			explosiveBodies[bodyId] = nil
		end
	end
end

function getExplosivePower(bodyId)
	if explosiveBodies[bodyId] == nil then
		return 0
	end
	
	return explosiveBodies[bodyId].power
end

-- Tool Functions

function isHoldingTool()
	return GetString("game.player.tool") == toolName and GetBool("game.player.canusetool")
end

function isFiringTool()
	local isHoldingIt = isHoldingTool()
	local isFiring = InputDown("usetool")
	
	return isFiring and isHoldingIt
end

function forceToolHeld()
	if GetString("game.player.tool") ~= toolName then
		SetString("game.player.tool", toolName)
	end
end

-- Particle Functions

function setupVoidParticles()
	ParticleReset()
	ParticleColor(0, 0, 0)
	ParticleRadius(0.25, 0.5)
	ParticleAlpha(0.5)
	ParticleGravity(0)
	ParticleDrag(0)
	ParticleCollide(1)
end

-- Action functions

function lookAtObject(dt)
	if currentBody == nil or currentBody == 0 then
		return
	end
	
	local currentBodyTransform = GetBodyTransform(currentBody)
	
	local objectMin, objectMax = GetBodyBounds(currentBody)
	
	local localFocusPoint = GetBodyCenterOfMass(currentBody)
	
	local objectCenter = TransformToParentPoint(currentBodyTransform, localFocusPoint)
	
	local cameraExtraLength = VecLength(VecSub(objectMax, objectMin)) / 2
	
	cameraLogic(dt, objectCenter, cameraExtraLength)
end

function cameraLogic(dt, objectCenter, cameraExtraLength)
	local cameraPos = VecCopy(cameraTransform.pos)
	
	local directionToBody = VecDir(cameraPos, objectCenter)
	
	local distanceToBody = VecDist(cameraPos, objectCenter)
	
	local xMovement = -InputValue("camerax")
	local yMovement = InputValue("cameray")
	
	if GetInputDown("Rotate_Object") then
		xMovement = 0
		yMovement = 0
	end
	
	local scroll = -InputValue("mousewheel")
	
	currCameraDistance = currCameraDistance + scroll * scrollSensitivity
	
	if currCameraDistance < 0 then
		currCameraDistance = 0
	end
	
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
end

function voidMovement(dt)
	local xMovement, yMovement, zMovement, xRot, yRot = getPlayerMovement()
	
	if xMovement == 0 and yMovement == 0 and zMovement == 0 then
		return
	end
	
	local movementDir = getMovementDir(voidPos, xMovement, yMovement, zMovement)
	
	voidPos = VecAdd(voidPos, VecScale(movementDir, dt * voidMovementSpeed))
end

function voidLogic(dt)
	setupVoidParticles()
	SpawnParticle(voidPos, Vec(0,0,0), dt * 10)
	
	voidMovement(dt)
	
	QueryRequire("physical dynamic")
	
	local minPos = VecSub(voidPos, Vec(voidRange, voidRange, voidRange))
	local maxPos = VecAdd(voidPos, Vec(voidRange, voidRange, voidRange))
	
	local nearbyBodies = QueryAabbBodies(minPos, maxPos)
	
	for i = 1, #nearbyBodies do
		local body = nearbyBodies[i]
		
		local bodyMass = GetBodyMass(body)
		
		if bodyMass < voidStrength then
			local bodyTransform = GetBodyTransform(body)
			local dirToVoid = VecDir(bodyTransform.pos, voidPos)
			local distToVoid = VecDist(voidPos, bodyTransform.pos)
			
			SetBodyVelocity(body, VecScale(dirToVoid, 25))
			
			if distToVoid < voidRange and voidBodies[body .. ""] == nil then
				voidStrength = voidStrength + voidStrengthPerMassGained * bodyMass
				voidBodies[body .. ""] = {}
				voidBodies[body .. ""][1] = body
				voidBodies[body .. ""][2] = bodyMass
			end
		end
	end
	
	for bodyTag, bodyData in pairs(voidBodies) do
		local bodyHandle = bodyData[1]
		local oldBodyMass = bodyData[2]
		
		local bodyTransform = GetBodyTransform(bodyHandle)
		local dirToVoid = VecDir(bodyTransform.pos, voidPos)
		
		if VecDist(voidPos, bodyTransform.pos) > voidRange then
			voidBodies[bodyTag] = nil
			voidStrength = voidStrength - voidStrengthPerMassGained * oldBodyMass
		end
		
		if voidStrength < voidStartStrength then
			voidStrength = voidStartStrength
		end
	end
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

	currCameraDistance = 0
end

function getPlayerMovement()
	local xMovement = 0
	local yMovement = 0
	local zMovement = 0
	
	local xRot = 0
	local yRot = 0
	
	if GetInputDown("Rotate_Object") then
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
	
	if GetInputMethod() == "MNK" then
		if InputDown("crouch") then
			yMovement = yMovement - 1
		end
	else
		if InputPressed("crouch") then
			controllerCrouchDown = true
		end
		
		if InputReleased("crouch") then
			controllerCrouchDown = false
		end
		
		if controllerCrouchDown then
			yMovement = yMovement - 1
		end
	end
	
	return xMovement, yMovement, zMovement, xRot, yRot
end

function getMovementDir(objectCenter, xMovement, yMovement, zMovement)
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
	
	return movementDirection
end

function possessionLogic()
	if currentBody == nil or currentBody == 0 or GetBodyMass(currentBody) <= 0 then
		return true
	end
	
	-- Get all movement inputs
	
	local xMovement, yMovement, zMovement, xRot, yRot = getPlayerMovement()
	
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
	
	local movementDirection = getMovementDir(objectCenter, xMovement, yMovement, zMovement)
	
	-- Scale according to speeds, and apply jump if jumping.
	
	local movementVec = VecScale(movementDirection, currentMovementSpeed * bodyMass)
	
	-- And finally apply that force
	
	ApplyBodyImpulse(currentBody, objectCenter, movementVec)
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
