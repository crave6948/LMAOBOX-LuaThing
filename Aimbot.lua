--[[
    Custom Aimbot for Lmaobox
    Author: github.com/lnx00
]]

---@alias AimTarget { entity : Entity, pos : Vector3, angles : EulerAngles, factor : number }
---@alias Rotation { yaw : number, pitch : number }
---@type boolean, lnxLib
local libLoaded, lnxLib = pcall(require, "lnxLib")
assert(libLoaded, "lnxLib not found, please install it!")
assert(lnxLib.GetVersion() >= 0.967, "LNXlib version is too old, please update it!")

local Math = lnxLib.Utils.Math
local WPlayer = lnxLib.TF2.WPlayer
local Helpers = lnxLib.TF2.Helpers

local Hitbox = {
    Head = 1,
    Neck = 2,
    Pelvis = 4,
    Body = 5,
    Chest = 7
}

local options = {
    AimKey = KEY_LCONTROL,
    AutoShoot = true,
    Silent = true,
    AimPos = Hitbox.Head,
    AimFov = 180
}

local currentTarget = nil

-- Returns the best target (lowest fov)
---@param me WPlayer
---@return AimTarget? target
local function GetBestTarget(me)
    local players = entities.FindByClass("CTFPlayer")
    local target = nil
    local lastFov = math.huge

    for _, entity in pairs(players) do
        if not entity then goto continue end
        if not entity:IsAlive() then goto continue end
        if entity:GetTeamNumber() == entities.GetLocalPlayer():GetTeamNumber() then goto continue end

        -- FOV Check
        local player = WPlayer.FromEntity(entity)
        local aimPos = player:GetHitboxPos(options.AimPos)
        local angles = Math.PositionAngles(me:GetEyePos(), aimPos)
        local fov = Math.AngleFov(angles, engine.GetViewAngles())
        if fov > options.AimFov then goto continue end

        -- Visiblity Check
        if not Helpers.VisPos(entity, me:GetEyePos(), aimPos) then goto continue end

        -- Add valid target
        if fov < lastFov then
            lastFov = fov
            target = { entity = entity, pos = aimPos, angles = angles, factor = fov }
        end

        ::continue::
    end

    return target
end
---@param v EulerAngles
---@return EulerAngles
function ClampAngles(v)
    local pitch = math.max(-89.0, math.min(89.0, Math.NormalizeAngle(v.pitch)));
    local yaw = Math.NormalizeAngle(v.yaw);
    return _G.EulerAngles(pitch,yaw,0)
end
---@param x number
---@return number
local function easeInOutQuint(x)
    if x < 0.5 then return 16 * x * x * x * x * x end
    return 1 - ((-2 * x + 2) ^ 5) / 2;
end
---@param old EulerAngles
---@param new EulerAngles
---@param factor number
---@return EulerAngles
function Smooth(old,new, factor)
    -- local diff = {new.yaw - old.yaw, new.pitch - old.pitch}
    -- local rotation = {old.yaw + (diff[1] * factor), old.pitch + (diff[2] * factor)}
    -- local an = _G.EulerAngles(rotation[2],rotation[1],0)
    local delta = ClampAngles(_G.EulerAngles(new.pitch - old.pitch,new.yaw - old.yaw,0))
    local aimPos = ClampAngles(_G.EulerAngles(old.pitch + (delta.pitch * factor), old.yaw + (delta.yaw * factor),0))
    return aimPos
end
local currentRotation = nil
local lastTarget = 0
local lastMS = os.clock()
---@param userCmd UserCmd
local function OnCreateMove(userCmd)
    if not input.IsButtonDown(options.AimKey) then 
        lastTarget = 0
        lastMS = os.clock()
        local pitch, yaw, roll = userCmd:GetViewAngles()
        currentRotation = _G.EulerAngles(pitch,yaw,roll)
        return end
    local me = WPlayer.GetLocal()
    if not me then return end
    if currentRotation == nil then
        local pitch, yaw, roll = userCmd:GetViewAngles()
        currentRotation = _G.EulerAngles(pitch,yaw,roll)
    end
    -- Get the best target
    currentTarget = GetBestTarget(me)
    if not currentTarget then 
        lastTarget = 0
        lastMS = os.clock()
        local pitch, yaw, roll = userCmd:GetViewAngles()
        currentRotation = _G.EulerAngles(pitch,yaw,roll)
    return end

    if (not lastTarget == currentTarget.entity:GetIndex()) or lastTarget == 0 then
        lastTarget = currentTarget.entity:GetIndex()
        lastMS = os.clock()
    end
    local cTime = os.clock()
    local sec = cTime - lastMS
    local performe = 0.3
    local yawab = Math.NormalizeAngle(currentTarget.angles.yaw - currentRotation.yaw)
    local pitchab = Math.NormalizeAngle(currentTarget.angles.pitch - currentRotation.pitch)
    local diffToTarget = math.sqrt(yawab^2 + pitchab^2)
    if diffToTarget > 7  and diffToTarget <= 30 then
        performe = 0.5
    elseif diffToTarget > 30 then
        performe = 0.75
    end
    local sec2 = sec / performe
    local factor = easeInOutQuint(math.min(sec2, 1))
    local rot = Smooth(currentRotation,currentTarget.angles,factor)
    -- Aim at the target
    if (cTime - lastMS > performe) then
        lastMS = cTime - (performe / 2)
    end
    userCmd:SetViewAngles(rot:Unpack())
    currentRotation = rot
    if not options.Silent then
        engine.SetViewAngles(rot)
    end
    -- Auto Shoot
    if options.AutoShoot then
        yawab = Math.NormalizeAngle(currentTarget.angles.yaw - currentRotation.yaw)
        pitchab = Math.NormalizeAngle(currentTarget.angles.pitch - currentRotation.pitch)
        diffToTarget = math.sqrt(yawab^2 + pitchab^2)
        if (diffToTarget <= 0.2) then
            userCmd.buttons = userCmd.buttons | IN_ATTACK
        end
    end
end

local function OnDraw()
    if not currentTarget then return end

    local me = WPlayer.GetLocal()
    if not me then return end
end

callbacks.Unregister("CreateMove", "LNX.Aimbot.CreateMove")
callbacks.Register("CreateMove", "LNX.Aimbot.CreateMove", OnCreateMove)

callbacks.Unregister("Draw", "LNX.Aimbot.Draw")
callbacks.Register("Draw", "LNX.Aimbot.Draw", OnDraw)

--[[
    Custom Aimbot for Lmaobox
    Author: github.com/lnx00
]]

-- ---@alias AimTarget { entity : Entity, pos : Vector3, angles : EulerAngles, factor : number }

-- ---@type boolean, lnxLib
-- local libLoaded, lnxLib = pcall(require, "lnxLib")
-- assert(libLoaded, "lnxLib not found, please install it!")
-- assert(lnxLib.GetVersion() >= 0.967, "LNXlib version is too old, please update it!")

-- local Math = lnxLib.Utils.Math
-- local WPlayer = lnxLib.TF2.WPlayer
-- local Helpers = lnxLib.TF2.Helpers

-- local Hitbox = {
--     Head = 1,
--     Neck = 2,
--     Pelvis = 4,
--     Body = 5,
--     Chest = 7
-- }

-- local options = {
--     AimKey = KEY_LSHIFT,
--     AutoShoot = true,
--     Silent = true,
--     AimPos = Hitbox.Head,
--     AimFov = 90
-- }

-- local currentTarget = nil

-- -- Returns the best target (lowest fov)
-- ---@param me WPlayer
-- ---@return AimTarget? target
-- local function GetBestTarget(me)
--     local players = entities.FindByClass("CTFPlayer")
--     local target = nil
--     local lastFov = math.huge

--     for _, entity in pairs(players) do
--         if not entity then goto continue end
--         if not entity:IsAlive() then goto continue end
--         if entity:GetTeamNumber() == entities.GetLocalPlayer():GetTeamNumber() then goto continue end

--         -- FOV Check
--         local player = WPlayer.FromEntity(entity)
--         local aimPos = player:GetHitboxPos(options.AimPos)
--         local angles = Math.PositionAngles(me:GetEyePos(), aimPos)
--         local fov = Math.AngleFov(angles, engine.GetViewAngles())
--         if fov > options.AimFov then goto continue end

--         -- Visiblity Check
--         if not Helpers.VisPos(entity, me:GetEyePos(), aimPos) then goto continue end

--         -- Add valid target
--         if fov < lastFov then
--             lastFov = fov
--             target = { entity = entity, pos = aimPos, angles = angles, factor = fov }
--         end

--         ::continue::
--     end

--     return target
-- end

-- ---@param userCmd UserCmd
-- local function OnCreateMove(userCmd)
--     if not input.IsButtonDown(options.AimKey) then return end

--     local me = WPlayer.GetLocal()
--     if not me then return end

--     -- Get the best target
--     currentTarget = GetBestTarget(me)
--     if not currentTarget then return end

--     -- Aim at the target
--     userCmd:SetViewAngles(currentTarget.angles:Unpack())
--     if not options.Silent then
--         engine.SetViewAngles(currentTarget.angles)
--     end

--     -- Auto Shoot
--     if options.AutoShoot then
--         userCmd.buttons = userCmd.buttons | IN_ATTACK
--     end
-- end

-- local function OnDraw()
--     if not currentTarget then return end

--     local me = WPlayer.GetLocal()
--     if not me then return end
-- end

-- callbacks.Unregister("CreateMove", "LNX.Aimbot.CreateMove")
-- callbacks.Register("CreateMove", "LNX.Aimbot.CreateMove", OnCreateMove)

-- callbacks.Unregister("Draw", "LNX.Aimbot.Draw")
-- callbacks.Register("Draw", "LNX.Aimbot.Draw", OnDraw)