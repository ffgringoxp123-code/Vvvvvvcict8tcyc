repeat task.wait() until game:IsLoaded()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StatsService = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local CoreGui = (gethui and gethui()) or game:GetService("CoreGui")
local Camera = workspace.CurrentCamera
local SwordAPI = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SwordAPI")
local player = Players.LocalPlayer

local function parryContextAllowed()
 local c=player.Character local h=c and c:FindFirstChildOfClass("Humanoid") local r=c and (c.PrimaryPart or c:FindFirstChild("HumanoidRootPart"))
 if not c or not h or h.Health<=0 or not r or c:GetAttribute("Stunned") or c:GetAttribute("DoNotParry") or c:GetAttribute("IsFrozen") then return false end
 if c.Parent==workspace:FindFirstChild("Alive") then return true end
 if player:GetAttribute("LobbyParry") and not player:GetAttribute("InLobbyParryCooldown") then return true end
 if player:GetAttribute("LobbyTraining") and c.Parent==workspace:FindFirstChild("Dead") then return true end
 local sp=workspace:FindFirstChild("Spawn") local lt=sp and sp:FindFirstChild("LobbyTraining") local area=lt and lt:FindFirstChild("TrainingArea")
 if area and area:IsA("BasePart") then local q=area.CFrame:PointToObjectSpace(r.Position) return math.abs(q.X)<=area.Size.X/2+2 and math.abs(q.Z)<=area.Size.Z/2+2 and math.abs(q.Y)<=area.Size.Y/2+20 end
 return false
end

do
 local env=getgenv() local host=(gethui and gethui()) or game:GetService("CoreGui") local protect=protect_gui or protectgui or syn and syn.protect_gui
 local function cloak(g) if not g then return end pcall(function() g.Name=game:GetService("HttpService"):GenerateGUID(false):gsub("-",""):sub(1,18) g.ResetOnSpawn=false end) if protect then pcall(protect,g) end if set_hidden_gui then pcall(set_hidden_gui,g,true) end if host and g.Parent~=host then pcall(function() g.Parent=host end) end end
 env.CSKRCloakGui=cloak
 env.CSKRScrambleUI=function(instance) if instance then pcall(function() for _,v in ipairs(instance:GetDescendants()) do if v:IsA("GuiObject") then v.Name=game:GetService("HttpService"):GenerateGUID(false):gsub("-",""):sub(1,18) end end end) end end
 env.GameSecure=setmetatable({},{__index=function(_,k) if k=="GetService" then return function(_,n) return (cloneref or function(x)return x end)(game:GetService(n)) end end return game[k] end})
 if not env.CSKRSecurityProbe then env.CSKRSecurityProbe=true task.spawn(function() while true do local st=os.clock() local fin=false task.delay(2,function() fin=true end) while not fin and os.clock()-st<4 do RunService.RenderStepped:Wait() end if not fin then warn("[SKR Security] scheduler freeze") end task.wait(5) end end) end
end

local cfg = {
parry = true,
spam = false,
trigger = false,
cps = 200,
accuracy = 50,
randomPingAccuracy = false,
autoSpam = false,
spamThreshold = 0,
distanceMultiplier = 1.0,
targetChangeStop = false,
aiPatterns = true,
aiDetection = true,
abilityDetections = true,
animfix = true,
showStats = true,
showSpamUI = true,
showTriggerUI = true,
curveType = 'straight',
showBindWindow = false,
spamBindKey = "P"
}

cfg.spamThreshold = math.max(0, cfg.spamThreshold or 0)
cfg.distanceMultiplier = math.max(0.8, cfg.distanceMultiplier or 1.0)

local RuntimeAccuracy = math.clamp(tonumber(cfg.accuracy) or 50,1,100)
task.spawn(function() while task.wait(1) do SaveSKRConfig() end end)
getgenv().SaveSKRConfig=SaveSKRConfig
getgenv().LoadSKRConfig=LoadSKRConfig
local spamBindKey = cfg.spamBindKey or "P"
local isWaitingForBind = false
local parried_balls = {}
local triggered_balls = {}
local AnimationCache = {}
local spamActive = cfg.spam == true
local lastSpamTime = 0

local Det = {
 infinity=false,
 deathslash=false,
 timehole=false,
 phantom=false,
 dribble=false,
 pull=false,
 singularity=false,
 forcefield=false,
 slashes=false,
 slashesCount=0,
 infinityEnabled=false,
 deathslashEnabled=false,
 timeholeEnabled=false,
 phantomEnabled=false,
 dribbleEnabled=false,
 pullEnabled=false,
 singularityEnabled=false,
 forcefieldEnabled=false,
 slashesEnabled=false,
 slashesParryDelay=0.05,
 slashesMaxCount=36,
 staffEnabled=false
}

local DetectionNet = ReplicatedStorage:FindFirstChild("Packages")
DetectionNet = DetectionNet and DetectionNet:FindFirstChild("_Index")
DetectionNet = DetectionNet and DetectionNet:FindFirstChild("sleitnick_net@0.1.0")
DetectionNet = DetectionNet and DetectionNet:FindFirstChild("net")

local function DetectionBlocked()
 if not cfg.abilityDetections then return false end
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 return (Det.infinityEnabled and Det.infinity)
 or (Det.deathslashEnabled and Det.deathslash)
 or (Det.timeholeEnabled and Det.timehole)

 or (Det.phantomEnabled and Det.phantom)
 or (Det.dribbleEnabled and Det.dribble)
 or (Det.pullEnabled and Det.pull)
 or (Det.slashesEnabled and Det.slashes)
 or (Det.singularityEnabled and (Det.singularity or (root and root:FindFirstChild("SingularityCape")~=nil)))
 or (Det.forcefieldEnabled and Det.forcefield)
end

local function AbilityBlocked()
 return DetectionBlocked()
end

pcall(function()
 local remote=ReplicatedStorage.Remotes:FindFirstChild("InfinityBall")
 if remote then remote.OnClientEvent:Connect(function(_,v) Det.infinity=v and true or false end) end
end)

pcall(function()
 local remote=ReplicatedStorage.Remotes:FindFirstChild("DeathBall")
 if remote then remote.OnClientEvent:Connect(function(_,v) Det.deathslash=v and true or false end) end
end)

pcall(function()
 local remotes=ReplicatedStorage:FindFirstChild("Remotes")
 local pull=remotes and (remotes:FindFirstChild("PlrPulled") or remotes:FindFirstChild("PlrPulsed"))
 if pull then
  pull.OnClientEvent:Connect(function(a,b)
   if type(a)=="boolean" then
    Det.pull=a
   elseif type(b)=="boolean" then
    Det.pull=b
   else
    Det.pull=true
    task.delay(1.5,function() Det.pull=false end)
   end
  end)
 end
end)

pcall(function()
 local remotes=ReplicatedStorage:FindFirstChild("Remotes")
 local pull=remotes and remotes:FindFirstChild("PlrPulsed")
 if pull then
  pull.OnClientEvent:Connect(function(a,b)
   if type(a)=="boolean" then
    Det.pull=a
   elseif type(b)=="boolean" then
    Det.pull=b
   else
    Det.pull=true
    task.delay(1.5,function() Det.pull=false end)
   end
  end)
 end
end)

pcall(function()
 local char=player.Character or player.CharacterAdded:Wait()
 local function watch(c)
  c.AttributeChanged:Connect(function(attr)
   if attr=="PassiveLock_ForceField" then
    Det.forcefield=c:GetAttribute("PassiveLock_ForceField")==true
   end
  end)
  Det.forcefield=c:GetAttribute("PassiveLock_ForceField")==true
 end
 watch(char)
 player.CharacterAdded:Connect(function(c)
  Det.forcefield=false
  watch(c)
 end)
end)

if DetectionNet then
 local TimeHoleActivate=DetectionNet:FindFirstChild("RE/TimeHoleActivate")
 local TimeHoleDeactivate=DetectionNet:FindFirstChild("RE/TimeHoleDeactivate")
 if TimeHoleActivate then
  TimeHoleActivate.OnClientEvent:Connect(function(p)
   if p==player or p==player.Name or p and p.Name==player.Name then Det.timehole=true end
  end)
 end
 if TimeHoleDeactivate then
  TimeHoleDeactivate.OnClientEvent:Connect(function() Det.timehole=false end)
 end
 local SlashesActivate=DetectionNet:FindFirstChild("RE/SlashesOfFuryActivate")
 local SlashesEnd=DetectionNet:FindFirstChild("RE/SlashesOfFuryEnd")
 local SlashesCatch=DetectionNet:FindFirstChild("RE/SlashesOfFuryCatch")
 local SlashesParry=DetectionNet:FindFirstChild("RE/SlashesOfFuryParry")
 if SlashesActivate then
  SlashesActivate.OnClientEvent:Connect(function(p)
   if not p or p==player or p==player.Name or p.Name==player.Name then
    Det.slashes=true
    Det.slashesCount=0
   end
  end)
 end
 if SlashesEnd then
  SlashesEnd.OnClientEvent:Connect(function()
   Det.slashes=false
   Det.slashesCount=0
  end)
 end
 if SlashesParry then
  SlashesParry.OnClientEvent:Connect(function()
   Det.slashesCount+=1
  end)
 end
 if SlashesCatch then
  SlashesCatch.OnClientEvent:Connect(function()
   if not Det.slashesEnabled then return end
   task.spawn(function()
    while Det.slashes and Det.slashesCount<Det.slashesMaxCount do
     local fn=getgenv().CSKR_SendParry
     if type(fn)=="function" then fn() end
     task.wait(Det.slashesParryDelay)
    end
   end)
  end)
 end
end

task.spawn(function()
 while task.wait(0.15) do
  local ball
  local folder=workspace:FindFirstChild("Balls")
  if folder then
   for _,v in ipairs(folder:GetChildren()) do
    if v:GetAttribute("realBall") then ball=v break end
   end
  end
  Det.dribble=ball and (ball:GetAttribute("Dribble")==true or ball:GetAttribute("Dribbling")==true or ball:FindFirstChild("Dribble")~=nil or ball:FindFirstChild("Dribbling")~=nil) or false
 end
end)

task.spawn(function()
 local runtime=workspace:FindFirstChild("Runtime") or workspace:WaitForChild("Runtime",15)
 if runtime then
  runtime.ChildAdded:Connect(function(o)
   if o.Name~="maxTransmission" and o.Name~="transmissionpart" then return end
   local weld=o:FindFirstChildWhichIsA("WeldConstraint")
   local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
   if weld and root and weld.Part1==root then
    Det.phantom=true
    task.delay(1,function() Det.phantom=false end)
   end
  end)
 end
end)

getgenv().CSKRDetectionState=Det
getgenv().CSKRAbilityDetectionState=Det

local function GetPing()
local success, result = pcall(function()
return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()
end)
return success and result or 100
end
task.spawn(function()
 while task.wait(1) do
  if cfg.randomPingAccuracy then
   local ping=GetPing()
   if ping>=90 then RuntimeAccuracy=4
   elseif ping<=50 then RuntimeAccuracy=math.random(70,100)
   else RuntimeAccuracy=math.clamp(tonumber(cfg.accuracy) or 50,1,100) end
  else RuntimeAccuracy=math.clamp(tonumber(cfg.accuracy) or 50,1,100) end
 end
end)

local AI={ping=100,frame=1/60,jitter=0,extra=0,last=0,motion=setmetatable({},{__mode="k"})}
RunService.Heartbeat:Connect(function(dt) local old=AI.frame AI.frame=old+((dt or 1/60)-old)*.12 AI.jitter=AI.jitter+(math.abs((dt or 1/60)-old)-AI.jitter)*.15 if os.clock()-AI.last>.25 then AI.last=os.clock() local p=GetPing() AI.ping=AI.ping+(p-AI.ping)*.22 end if not cfg.aiDetection then AI.extra=0 elseif AI.ping>=220 or AI.frame>=.065 then AI.extra=.05 elseif AI.ping>=140 or AI.frame>=.035 then AI.extra=.028 elseif AI.ping>=85 then AI.extra=.012 else AI.extra=0 end end)

local function ClosestOpponent() local root=player.Character and player.Character.PrimaryPart local alive=workspace:FindFirstChild("Alive") if not root or not alive then return end local best,res=math.huge,nil for _,c in ipairs(alive:GetChildren()) do if c~=player.Character and c.PrimaryPart then local d=(c.PrimaryPart.Position-root.Position).Magnitude if d<best then best,res=d,c end end end return res end

local function CalculateParryDistance(ball,velocity,root)
 local speed=velocity.Magnitude local ping=GetPing() local capped=math.min(math.max(speed-9.5,0),650) local div=(2.4+capped*.002)*(0.75+(math.clamp(RuntimeAccuracy,1,100)-1)*(3/99)) local modern=math.clamp(ping/100,5,17)+math.max(speed/div,9.5) local legacy=speed/math.max(2.4,RuntimeAccuracy/8)+ping/10 local result=math.max(modern,legacy)
 if cfg.aiDetection then result=result+math.clamp(speed*AI.extra,0,30) if speed>=750 then result=math.max(result,9.5+speed*.025) end end
 if cfg.aiPatterns then local now=os.clock() local h=AI.motion[ball] if h then local dt=math.clamp(now-h.time,1/240,.15) local acc=(velocity-h.velocity).Magnitude/dt local turn=velocity.Magnitude>0 and h.velocity.Magnitude>0 and math.acos(math.clamp(velocity.Unit:Dot(h.velocity.Unit),-1,1)) or 0 result=result+math.clamp(acc*.0015+speed*turn*.07,0,20) end AI.motion[ball]={velocity=velocity,time=now} local o=ClosestOpponent() if o and o.PrimaryPart then local to=root.Position-o.PrimaryPart.Position if to.Magnitude>0 then result=result+math.clamp(math.max(o.PrimaryPart.AssemblyLinearVelocity:Dot(to.Unit),0)*.1,0,12) end end end
 return result
end

local Lerp_Radians = 0
local Last_Warping = tick()
local function Is_Curved(ball)
local Zoomies = ball:FindFirstChild("zoomies")
if not Zoomies then return false end
local Velocity = Zoomies.VectorVelocity
local Character = player.Character
if not Character or not Character.PrimaryPart then return false end
local distanceToBall = (Character.PrimaryPart.Position - ball.Position).Magnitude
if distanceToBall <= 25 then return false end
local Speed = Velocity.Magnitude
local Direction = (Character.PrimaryPart.Position - ball.Position).Unit
local Dot = Direction:Dot(Velocity.Unit)
local Ping = GetPing() / 1000
local Distance = (Character.PrimaryPart.Position - ball.Position).Magnitude
local Reach_Time = Distance / Speed - Ping
local Radians = math.rad(math.asin(math.clamp(Dot, -1, 1)))
Lerp_Radians = Lerp_Radians + (Radians - Lerp_Radians) * 0.8
if Lerp_Radians < 0.018 then Last_Warping = tick() end
if (tick() - Last_Warping) < (Reach_Time / 1.5) then return true end
return Dot < (0.5 - Ping)
end

local function GetParryAnimation()
local char = player.Character
local currentSword = char and char:GetAttribute("CurrentlyEquippedSword")
if not currentSword then return SwordAPI.Collection.Default:FindFirstChild("GrabParry") end
if AnimationCache[currentSword] then return AnimationCache[currentSword] end
local success, swordData = pcall(function()
return ReplicatedStorage.Shared.ReplicatedInstances.Swords.GetSword:Invoke(currentSword)
end)
if success and type(swordData) == "table" then
for _, obj in pairs(SwordAPI.Collection:GetChildren()) do
if obj.Name == swordData.AnimationType then
local anim = obj:FindFirstChild("GrabParry") or obj:FindFirstChild("Grab")
if anim then AnimationCache[currentSword] = anim return anim end
end
end
end
return SwordAPI.Collection.Default:FindFirstChild("GrabParry")
end

local function PlayParryAnimation()
if not cfg.animfix then return end
local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
if not hum or not hum:FindFirstChild("Animator") then return end
local animation = GetParryAnimation()
if not animation then return end
for _, track in pairs(hum.Animator:GetPlayingAnimationTracks()) do
if track.Name:find("Grab") or track.Name:find("Parry") then track:Stop(0.1) end
end
local track = hum.Animator:LoadAnimation(animation)
track:Play(0, 1, 1)
end

local function ApplyCurveToCFrame(baseCFrame)
if not cfg.curveType or cfg.curveType == 'straight' then return baseCFrame end
local rotation = CFrame.new()
if cfg.curveType == 'backwards' then rotation = CFrame.Angles(0, math.rad(180), 0)
elseif cfg.curveType == 'down' then rotation = CFrame.Angles(math.rad(-45), 0, 0)
elseif cfg.curveType == 'up' then rotation = CFrame.Angles(math.rad(45), 0, 0)
elseif cfg.curveType == 'left' then rotation = CFrame.Angles(0, math.rad(-90), 0)
elseif cfg.curveType == 'right' then rotation = CFrame.Angles(0, math.rad(90), 0)
elseif cfg.curveType == 'random' then rotation = CFrame.Angles(0, math.random() * math.pi * 2, 0)
end
return baseCFrame * rotation
end

local function GetParryData()
local viewportSize = Camera.ViewportSize
local centerPos = { viewportSize.X / 2, viewportSize.Y / 2 }
local events = {}
for _, v in pairs(workspace.Alive:GetChildren()) do
if v ~= player.Character and v:FindFirstChild("HumanoidRootPart") then
local screenPos, isOnScreen = Camera:WorldToScreenPoint(v.HumanoidRootPart.Position)
if isOnScreen then events[tostring(v)] = screenPos end
end
end
return Camera.CFrame, events, centerPos
end

local recentParries=0

local _token
for _, Function in getgc(true) do
    if type(Function) ~= 'function' then continue end
    local ok, src = pcall(debug.info, Function, 's')
    if not ok or type(src) ~= 'string' or not src:find('PRY', 1, true) then continue end
    for _, value in debug.getupvalues(Function) do
        if type(value) == 'function' then
            _token = value
            break
        end
    end
    if _token then break end
end

local function _tokenize(_remote_uid)
    local time = tostring(math.floor(workspace:GetServerTimeNow() * 100))
    local key = _token(_remote_uid, 'TIME')
    local characters = table.create(#time)
    for index = 1, #time do
        characters[index] = string.char(bit32.bxor(
            (string.byte(time, index) + index) % 256,
            string.byte(key, (index - 1) % #key + 1)
        ))
    end
    return table.concat(characters)
end

local _reverted = {}
local _originalMt = {}
local _captured = nil

local function _is_valid(args)
    return #args == 8
        and type(args[2]) == "string" and type(args[3]) == "string"
        and type(args[4]) == "number" and typeof(args[5]) == "CFrame"
        and type(args[6]) == "table" and type(args[7]) == "table"
        and type(args[8]) == "boolean"
end

local function _hook(remote)
    local mt = getrawmetatable(remote)
    if not mt or _originalMt[mt] then return end
    _originalMt[mt] = true
    setreadonly(mt, false)
    local old = mt.__index
    mt.__index = function(self, key)
        local isFire  = (key == 'FireServer'  and self:IsA('RemoteEvent'))
        local isInvok = (key == 'InvokeServer' and self:IsA('RemoteFunction'))
        if isFire or isInvok then
            return function(_, ...)
                local a = {...}
                if _is_valid(a) then
                    if not _reverted[self] then _reverted[self] = a end
                    if not _captured then
                        _captured = { remote = self, isInvoke = isInvok }
                        print("[SKR] CAPTURED parry remote -> ready:", self:GetFullName())
                    end
                end
                if isInvok then return old(self, key)(_, unpack(a)) end
                return old(self, key)(_, unpack(a))
            end
        end
        return old(self, key)
    end
    setreadonly(mt, true)
end

for _, remote in pairs(ReplicatedStorage:GetDescendants()) do
    if remote:IsA('RemoteEvent') or remote:IsA('RemoteFunction') then
        pcall(_hook, remote)
    end
end
ReplicatedStorage.ChildAdded:Connect(function(child)
    if child:IsA('RemoteEvent') or child:IsA('RemoteFunction') then
        pcall(_hook, child)
    end
end)

local function RemoteReady()
    return _captured ~= nil and _token ~= nil
end

local function SendParry()
    if not RemoteReady() or not parryContextAllowed() or AbilityBlocked() then return false end
    local remote = _captured.remote
    local cap = _reverted[remote] or (_captured.args)
    if not cap then return false end

    local okTok, token = pcall(_tokenize, cap[2])
    if not (okTok and token) then return false end

    local cf, events, mouse = GetParryData()
    cf = ApplyCurveToCFrame(cf)

    local packet = { cap[1], cap[2], token, cap[4] or 0.5, cf, events, mouse, false }

    local fired
    if _captured.isInvoke then
        fired = pcall(function() remote:InvokeServer(unpack(packet)) end)
    else
        fired = pcall(function() remote:FireServer(unpack(packet)) end)
    end

    if fired then
        recentParries = (recentParries or 0) + 1
        task.delay(.5, function() recentParries = math.max((recentParries or 1) - 1, 0) end)
    end
    if fired and cfg.animfix then task.spawn(PlayParryAnimation) end
    return fired
end

getgenv().CSKR_SendParry=SendParry

local function ProcessAutoParry(ball)
if not cfg.parry or spamActive then return end
local bID = ball:GetDebugId()
if ball:GetAttribute("target") ~= player.Name or parried_balls[bID] then return end
if Is_Curved(ball) then return end
local charPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
if not charPart then return end
local velocity = ball.zoomies.VectorVelocity
local ballPos = ball.Position
local playerPos = charPart.Position
local dist = (playerPos - ballPos).Magnitude
local threshold = CalculateParryDistance(ball, velocity, charPart)
if dist <= threshold or dist <= 20 then
parried_balls[bID] = true
SendParry()
ball:GetAttributeChangedSignal("target"):Once(function() parried_balls[bID] = nil end)
end
end

local function ProcessTriggerBot(ball)
if not cfg.trigger or spamActive then return end
local bID = ball:GetDebugId()
if ball:GetAttribute("target") == player.Name and not triggered_balls[bID] then
triggered_balls[bID] = true
SendParry()
ball:GetAttributeChangedSignal("target"):Once(function() triggered_balls[bID] = nil end)
end
end

local AS={target=nil,targetTime=0,lastCheck=0,lastFire=0,trackedBall=nil,targetConn=nil,engagedTarget=nil,abortCycle=false}
local function ResetAutoSpamTargetGuard()
 if AS.targetConn then AS.targetConn:Disconnect() AS.targetConn=nil end
 AS.trackedBall=nil
 AS.engagedTarget=nil
 AS.abortCycle=false
end
local function TrackAutoSpamTarget(ball)
 if AS.trackedBall==ball then return end
 ResetAutoSpamTargetGuard()
 AS.trackedBall=ball
 AS.engagedTarget=ball:GetAttribute("target")
 AS.targetConn=ball:GetAttributeChangedSignal("target"):Connect(function()
  if AS.trackedBall~=ball then return end
  local liveTarget=ball:GetAttribute("target")
  if cfg.targetChangeStop then
   if not AS.engagedTarget then AS.engagedTarget=liveTarget
   elseif liveTarget and liveTarget~=AS.engagedTarget then AS.engagedTarget=liveTarget AS.abortCycle=true end
  else AS.engagedTarget=liveTarget AS.abortCycle=false end
 end)
end

local function ProcessAutoSpam(ball)
 if not cfg.autoSpam or not parryContextAllowed() then ResetAutoSpamTargetGuard() return end
 local root=player.Character and player.Character.PrimaryPart local z=ball:FindFirstChild("zoomies")
 if not root or not z then return end

 TrackAutoSpamTarget(ball)
 local now=tick() if now-AS.lastFire<0.015 then return end AS.lastFire=now
 local target=ball:GetAttribute("target")

 if cfg.targetChangeStop and AS.abortCycle then AS.abortCycle=false return end

 if now-AS.lastCheck>.1 then AS.target=ClosestOpponent() AS.lastCheck=now AS.targetTime=now end
 local enemy=AS.target if not enemy or not enemy.PrimaryPart or not target then return end

 local speed=z.VectorVelocity.Magnitude if speed<.001 then return end
 local ping=math.clamp(GetPing()/10,1,16)

 local distMult = math.max(cfg.distanceMultiplier or 1.0, 0.8)
 local max=(ping+math.min(speed/6,255)+math.clamp(speed*AI.extra,0,35))*distMult
 local bd=(root.Position-ball.Position).Magnitude local ed=(root.Position-enemy.PrimaryPart.Position).Magnitude
 if bd>max or ed>max then return end

 local dot=(root.Position-ball.Position).Unit:Dot(z.VectorVelocity.Unit)
 local acc=max-math.clamp(dot,-1,0)*(5-math.min(speed/5,5))

 local spamGate = math.max(cfg.spamThreshold or 0, 0)
 if (target==enemy.Name or target==player.Name) and bd<=acc and ed<=acc
    and recentParries>=spamGate then
   SendParry()
 end
end

task.spawn(function()
while true do
if spamActive and RemoteReady() then
local delay = 1 / math.max(cfg.cps or 200, 1)
if tick() - lastSpamTime >= delay then SendParry() lastSpamTime = tick() end
end
task.wait(0.001)
end
end)

RunService.Heartbeat:Connect(function()
if not RemoteReady() then return end
local ball=nil
local balls=workspace:FindFirstChild("Balls")
if balls then for _,v in pairs(balls:GetChildren()) do if v:GetAttribute("realBall") then ball=v break end end end
if ball then
 if cfg.trigger then ProcessTriggerBot(ball)
 elseif cfg.parry and not spamActive then ProcessAutoParry(ball) end
 ProcessAutoSpam(ball)
end
local training=workspace:FindFirstChild("TrainingBalls")
if training and parryContextAllowed() then
 for _,v in ipairs(training:GetChildren()) do
  if v:GetAttribute("realBall") then
   if cfg.parry then ProcessAutoParry(v) end
   ProcessAutoSpam(v)
   break
  end
 end
end
end)

ReplicatedStorage.Remotes.ParrySuccess.OnClientEvent:Connect(function()
local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
if not hum or not hum:FindFirstChild("Animator") then return end
for _, track in pairs(hum.Animator:GetPlayingAnimationTracks()) do
if track.Name:find("Grab") or track.Name:find("Parry") then track:Stop(0.1) end
end
end)

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/ffgringoxp123-code/Code/refs/heads/main/Uikitty_with_ColorPicker.lua.txt"))()

local UI = Library._new()

local MainCat = UI:create_category("Main")
local Parry = MainCat:create_tab("Parry", "rbxassetid://swords")

local ParryLeft = Parry:create_group("Auto Parry", "left")

ParryLeft:create_toggle("auto_parry", {
    title = "Auto Parry",
    default = cfg.parry == true,
    callback = function(value) cfg.parry = value end,
})

ParryLeft:create_slider("parry_accuracy", {
    title = "Parry Accuracy",
    minimum = 1,
    maximum = 100,
    default = RuntimeAccuracy,
    rounding = true,
    callback = function(value)
        cfg.accuracy = value
        if not cfg.randomPingAccuracy then RuntimeAccuracy = value end
    end,
})

ParryLeft:create_toggle("humanizer", {
    title = "Humanizer",
    default = cfg.randomPingAccuracy == true,
    callback = function(value)
        cfg.randomPingAccuracy = value
        if not value then RuntimeAccuracy = math.clamp(tonumber(cfg.accuracy) or 50, 1, 100) end
    end,
})

ParryLeft:create_slider("humanizer_accuracy", {
    title = "Humanizer Accuracy",
    minimum = 1,
    maximum = 100,
    default = RuntimeAccuracy,
    rounding = true,
    callback = function(value)
        if cfg.randomPingAccuracy then RuntimeAccuracy = math.clamp(value, 1, 100) end
    end,
})

ParryLeft:create_dropdown("curve_type", {
    title = "Curve Type",
    options = { "straight", "backwards", "up", "down", "left", "right", "random" },
    default = cfg.curveType or "straight",
    callback = function(value) cfg.curveType = value end,
})

local ParryRight = Parry:create_group("Auto Spam", "right")

ParryRight:create_toggle("auto_spam", {
    title = "Auto Spam",
    default = cfg.autoSpam == true,
    callback = function(value)
        cfg.autoSpam = value
        if not value then ResetAutoSpamTargetGuard() end
    end,
})

ParryRight:create_toggle("target_change_stop", {
    title = "Target Change Stop",
    default = cfg.targetChangeStop == true,
    callback = function(value)
        cfg.targetChangeStop = value
        ResetAutoSpamTargetGuard()
    end,
})

ParryRight:create_toggle("animation_fix", {
    title = "Animation Fix",
    default = cfg.animfix == true,
    callback = function(value) cfg.animfix = value end,
})

ParryRight:create_slider("parry_threshold", {
    title = "Parry Threshold",
    minimum = 0,
    maximum = 10,
    default = math.max(0, cfg.spamThreshold or 0),
    rounding = true,
    callback = function(value) cfg.spamThreshold = value end,
})

ParryRight:create_slider("distance_multiplier", {
    title = "Distance Multiplier",
    minimum = 1,
    maximum = 300,
    default = math.round(math.max(cfg.distanceMultiplier or 1.0, 0.8) * 100),
    rounding = true,
    callback = function(value) cfg.distanceMultiplier = math.max(value / 100, 0.8) end,
})


local __unlockAllInit = false
local __unlockAllEnable = nil

local function __initUnlockAllBackend()
    if __unlockAllInit then return true end
    local ok, err = pcall(function()
        repeat task.wait() until game:IsLoaded()

        local getgenv = getgenv
        local task = task
        local RunService = game:GetService("RunService")
        local Players = game:GetService("Players")
        local LocalPlayer = Players.LocalPlayer
        local UserInputService = game:GetService("UserInputService")
        local TweenService = game:GetService("TweenService")
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local HttpService = game:GetService("HttpService")

        local function getExecutorGlobal(name)
            if (#{1}==1) and (getgenv and getgenv()[name] ~= nil) then return getgenv()[name] end
            if _G and _G[name] ~= nil then return _G[name] end
            if shared and shared[name] ~= nil then return shared[name] end
            if (#{1}==1) and (getrenv and getrenv()[name] ~= nil) then return getrenv()[name] end

            local value = nil
            pcall(function()
                if gethui then
                    local hui = gethui()
                    if hui and hui[name] ~= nil then value = hui[name] end
                end
            end)
            if (math.floor(1.5)==1) and (value ~= nil) then return value end

            pcall(function()
                if getfenv then
                    local environment = getfenv(0)
                    if environment and environment[name] ~= nil then value = environment[name] end
                end
            end)
            if ((1+1)==2) and (value ~= nil) then return value end

            return nil
        end

            local SKIN_LAST_EQUIPPED_CONFIG_KEY = "Skin.LastEquippedSword"
            local EXPLOSION_LAST_EQUIPPED_CONFIG_KEY = "Skin.LastEquippedExplosion"
            local AUTO_CONFIG_FILE = "Azure/auto_config.json"

            local function readAzureAutoConfig()
                local data = {}
                pcall(function()
                    if isfile and isfile(AUTO_CONFIG_FILE) then
                        local decoded = HttpService:JSONDecode(readfile(AUTO_CONFIG_FILE))
                        if type(decoded) == "table" then
                            data = decoded
                        end
                    end
                end)
                return data
            end

            local function writeAzureAutoConfig(data)
                pcall(function()
                    if (type("")=="string") and (isfolder and makefolder and not isfolder("Azure")) then
                        _VM(0)
                    end
                    if writefile then
                        writefile(AUTO_CONFIG_FILE, HttpService:JSONEncode(data or {}))
                    end
                end)
            end

            local function loadLastEquippedSword()
                local data = readAzureAutoConfig()
                local saved = data[SKIN_LAST_EQUIPPED_CONFIG_KEY]
                return type(saved) == "string" and saved or ""
            end

            local function loadLastEquippedExplosion()
                local data = readAzureAutoConfig()
                local saved = data[EXPLOSION_LAST_EQUIPPED_CONFIG_KEY]
                return type(saved) == "string" and saved or ""
            end

            getgenv().saveLastEquippedSword = function(swordName)
                if type(swordName) ~= "string" or swordName == "" then return end

                local autoConfig = getgenv()._azAutoConfig
                local data = autoConfig and autoConfig.Data
                if ((1+1)==2) and (type(data) ~= "table") then
                    data = readAzureAutoConfig()
                end

                data[SKIN_LAST_EQUIPPED_CONFIG_KEY] = swordName
                if autoConfig and type(autoConfig.Data) == "table" then
                    autoConfig.Data[SKIN_LAST_EQUIPPED_CONFIG_KEY] = swordName
                end
                writeAzureAutoConfig(data)
            end

            getgenv().saveLastEquippedExplosion = function(explosionName)
                if type(explosionName) ~= "string" or explosionName == "" then return end

                local autoConfig = getgenv()._azAutoConfig
                local data = autoConfig and autoConfig.Data
                if (0==0) and (type(data) ~= "table") then
                    data = readAzureAutoConfig()
                end

                data[EXPLOSION_LAST_EQUIPPED_CONFIG_KEY] = explosionName
                if autoConfig and type(autoConfig.Data) == "table" then
                    autoConfig.Data[EXPLOSION_LAST_EQUIPPED_CONFIG_KEY] = explosionName
                end
                writeAzureAutoConfig(data)
            end

            do
                local savedLastSword = loadLastEquippedSword()
                local savedLastExplosion = loadLastEquippedExplosion()
                getgenv().skinChanger = getgenv().skinChanger or savedLastSword ~= ""
                getgenv().swordModel = type(getgenv().swordModel) == "string" and getgenv().swordModel ~= "" and getgenv().swordModel or savedLastSword
                getgenv().swordAnimations = type(getgenv().swordAnimations) == "string" and getgenv().swordAnimations ~= "" and getgenv().swordAnimations or savedLastSword
                getgenv().swordFX = type(getgenv().swordFX) == "string" and getgenv().swordFX ~= "" and getgenv().swordFX or savedLastSword
                getgenv().explosionChanger = getgenv().explosionChanger or savedLastExplosion ~= ""
                getgenv().explosionFX = type(getgenv().explosionFX) == "string" and getgenv().explosionFX ~= "" and getgenv().explosionFX or savedLastExplosion
            end

            task.spawn(function()
                local rs = game:GetService("ReplicatedStorage")
                local swordInstancesInstance = rs:WaitForChild("Shared", 9e9):WaitForChild("ReplicatedInstances", 9e9):WaitForChild("Swords", 9e9)
                local swordInstances = require(swordInstancesInstance)

                local swordsController
                task.spawn(function()
                    while task.wait(0.25) and not swordsController do
                        local ok, conns = pcall(getconnections, rs.Remotes.FireSwordInfo.OnClientEvent)
                        if (({})~=nil) and (ok and conns) then
                            for _, v in ipairs(conns) do
                                if v.Function and islclosure and islclosure(v.Function) then
                                    local ok2, up = pcall(getupvalues, v.Function)
                                    if ok2 and #up == 1 and type(up[1]) == "table" then
                                        swordsController = up[1]
                                        break
                                    end
                                end
                            end
                        end
                    end
                end)

                local function getSlashName(swordName)
                    local ok, sln = pcall(function() return swordInstances:GetSword(swordName) end)
                    return (ok and sln and sln.SlashName) or "SlashEffect"
                end

                local function refreshSlashName()
                    local fxName = getgenv().swordFX ~= "" and getgenv().swordFX or getgenv().swordModel
                    if (1<2) and (fxName ~= "") then
                        getgenv().slashName = getSlashName(fxName)
                    else
                        getgenv().slashName = "SlashEffect"
                    end
                end
                refreshSlashName()

                local function setSword()
                    if not getgenv().skinChanger then return end
                    if not LocalPlayer.Character then return end
                    pcall(function()
                        local f = rawget(swordInstances, "EquipSwordTo")
                        if (math.floor(1.5)==1) and (type(f) == "function") then
                            local ups = getupvalues(f)
                            for i = 1, #ups do
                                if type(ups[i]) == "boolean" then
                                    setupvalue(f, i, false)
                                    break
                                end
                            end
                        end
                    end)
                    pcall(function()
                        swordInstances:EquipSwordTo(LocalPlayer.Character, getgenv().swordModel)
                    end)
                    task.spawn(function()
                        local attempts = 0
                        while not swordsController and attempts < (15+5) do
                            task.wait(0.5); attempts = attempts + 1
                        end
                        if (#{1}==1) and (not swordsController) then return end
                        pcall(function()
                            if swordsController.SetSword then
                                swordsController:SetSword(getgenv().swordAnimations ~= "" and getgenv().swordAnimations or getgenv().swordModel)
                            end
                        end)
                        pcall(function()
                            local targetSword = getgenv().swordFX ~= "" and getgenv().swordFX or getgenv().swordModel
                            if rs.Remotes:FindFirstChild("FireSwordInfo") then
                                rs.Remotes.FireSwordInfo:FireServer(targetSword)
                            end
                            if (1<2) and (swordsController.currentSword ~= nil) then
                                pcall(function() swordsController.currentSword = targetSword end)
                            end
                            if swordsController.SwordFX ~= nil then
                                pcall(function() swordsController.SwordFX = targetSword end)
                            end
                        end)
                    end)
                end

                local hookedFuncs = {}
                task.spawn(function()
                    local remotesToHook = {"ParrySuccessAll", "ParryAttempt", "ParrySuccess", "PlaySound", "PlayVisuals"}
                    while task.wait(1) do
                        for _, remoteName in ipairs(remotesToHook) do
                            local remote = rs.Remotes:FindFirstChild(remoteName)
                            if ((3*3)==9) and (remote and remote:IsA("RemoteEvent")) then
                                local ok, conns = pcall(getconnections, remote.OnClientEvent)
                                if ok and type(conns) == "table" then
                                    for _, v in ipairs(conns) do
                                        local func = v.Function
                                        if func and not hookedFuncs[func] then

                                            hookedFuncs[func] = true
                                            v:Disable()
                                            local targetFunc = func
                                            local ourFunc
                                            ourFunc = function(...)
                                                local args = { ... }

                                                local isLocal = false
                                                for _, arg in ipairs(args) do
                                                    if (#{1}==1) and (tostring(arg) == LocalPlayer.Name or (typeof(arg) == "Instance" and (arg == LocalPlayer.Character or arg == LocalPlayer))) then
                                                        isLocal = true
                                                        break
                                                    end
                                                end

                                                if isLocal and getgenv().skinChanger then
                                                    local fxSword = getgenv().swordFX ~= "" and getgenv().swordFX or getgenv().swordModel
                                                    refreshSlashName()

                                                    local swordFound = false
                                                    local slashFound = false

                                                    for i, arg in ipairs(args) do
                                                        if type(arg) == "string" then
                                                            if ((1+1)==2) and (fxSword ~= "" and not slashFound and (arg:match("Slash") or arg == "Default" or arg:match("Effect"))) then
                                                                args[i] = getgenv().slashName
                                                                slashFound = true
                                                            elseif fxSword ~= "" and not swordFound then
                                                                local isSword = false
                                                                pcall(function()
                                                                    if rs.Shared.ReplicatedInstances.Swords:FindFirstChild(arg) then
                                                                        isSword = true
                                                                    end
                                                                end)
                                                                if isSword or arg == LocalPlayer:GetAttribute("CurrentlyEquippedSword") then
                                                                    args[i] = fxSword
                                                                    swordFound = true
                                                                end
                                                            end
                                                        end
                                                    end

                                                    if (math.floor(1.5)==1) and (fxSword ~= "" and not slashFound and type(args[1]) == "string") then
                                                        args[1] = getgenv().slashName
                                                    end
                                                    if fxSword ~= "" and not swordFound and type(args[3]) == "string" then
                                                        args[3] = fxSword
                                                    end
                                                end
                                                if setthreadidentity then pcall(setthreadidentity, 2) end
                                                pcall(targetFunc, unpack(args))
                                            end
                                            hookedFuncs[ourFunc] = true
                                            remote.OnClientEvent:Connect(ourFunc)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end)

                getgenv().updateSword = function()
                    refreshSlashName()
                    if (#{1}==1) and (getgenv().skinChanger and getgenv().swordModel ~= "" and getgenv().saveLastEquippedSword) then
                        getgenv().saveLastEquippedSword(getgenv().swordModel)
                    end
                    setSword()
                end

                task.spawn(function()
                    while task.wait(1) do
                        if getgenv().skinChanger and getgenv().swordModel ~= "" then
                            local char = LocalPlayer.Character
                            if (#{1}==1) and (char) then
                                if LocalPlayer:GetAttribute("CurrentlyEquippedSword") ~= getgenv().swordModel then
                                    setSword()
                                end
                                if not char:FindFirstChild(getgenv().swordModel) then
                                    setSword()
                                end
                                for _, v in pairs(char:GetChildren()) do
                                    if (math.floor(1.5)==1) and (v:IsA("Model") and v.Name ~= getgenv().swordModel) then
                                        v:Destroy()
                                    end
                                    task.wait()
                                end
                            end
                        end
                    end
                end)

                LocalPlayer.CharacterAdded:Connect(function()
                    if getgenv().skinChanger then
                        getgenv().skinChanger = false
                        if getgenv().setSkinChangerToggleUI then getgenv().setSkinChangerToggleUI(false) end
                        task.wait(2)
                        getgenv().skinChanger = true
                        if ((1+1)==2) and (getgenv().setSkinChangerToggleUI) then getgenv().setSkinChangerToggleUI(true) end
                        task.wait(0.5)
                        pcall(function() getgenv().updateSword() end)
                    end
                end)
            end)

            task.spawn(function()
                local rs = game:GetService("ReplicatedStorage")
                local explosionHookedFuncs = {}

                local explosionDirectHooked = {}
                local deadFolderHooked = false
                local explosionModule = nil
                local bindableInvokeHooked = false
                local nativeExplosionSuppressorHooked = {}
                local pendingKillExplosionPosition = nil
                local pendingKillExplosionAt = 0
                local lastLocalKillAt = 0
                local lastLocalKillStatTotal = nil
                local killStatWatcherStarted = false
                local lastLocalExplosionPlayedAt = 0
                local lastLocalExplosionPlayedPosition = nil

                local function normalizeExplosionName(value)
                    return tostring(value or ""):lower():gsub("[^%w]", "")
                end

                local function getNetFolder()
                    local packages = rs:FindFirstChild("Packages")
                    local index = packages and packages:FindFirstChild("_Index")
                    local sleitnick = index and index:FindFirstChild("sleitnick_net@0.1.0")
                    return sleitnick and sleitnick:FindFirstChild("net")
                end

                local function getExplosionInstances()
                    local shared = rs:FindFirstChild("Shared")
                    local replicatedInstances = shared and shared:FindFirstChild("ReplicatedInstances")
                    return replicatedInstances and replicatedInstances:FindFirstChild("Explosions")
                end

                local function getExplosionDataFolder()
                    local misc = rs:FindFirstChild("Misc")
                    return misc and misc:FindFirstChild("DataExplosions")
                end

                local function getExplosionEffectsFolder()
                    return rs:FindFirstChild("ExplosionEffects")
                end

                local function getExplosionModule()
                    if explosionModule ~= nil then return explosionModule end
                    local instance = getExplosionInstances()
                    if instance and instance:IsA("ModuleScript") then
                        local ok, result = pcall(function()
                            return require(instance)
                        end)
                        explosionModule = ok and result or false
                    end
                    return explosionModule
                end

                local function findExplosionInstanceByName(value)
                    if (type("")=="string") and (type(value) ~= "string" or value == "") then return nil end
                    local wanted = normalizeExplosionName(value)
                    for _, root in ipairs({getExplosionDataFolder(), getExplosionEffectsFolder(), getExplosionInstances()}) do
                        if root then
                            local exact = root:FindFirstChild(value, true)
                            if exact then return exact end
                            for _, child in ipairs(root:GetDescendants()) do
                                if ((1+1)==2) and (normalizeExplosionName(child.Name) == wanted) then
                                    return child
                                end
                            end
                        end
                    end
                    return nil
                end

                local function findExplosionDataConfig(value)
                    if type(value) ~= "string" or value == "" then return nil end
                    local dataFolder = getExplosionDataFolder()
                    if not dataFolder then return nil end

                    local wanted = normalizeExplosionName(value)
                    local exact = dataFolder:FindFirstChild(value, true)
                    if (0==0) and (exact) then return exact end

                    for _, child in ipairs(dataFolder:GetDescendants()) do
                        if normalizeExplosionName(child.Name) == wanted then
                            return child
                        end
                        for _, attributeValue in pairs(child:GetAttributes()) do
                            if type(attributeValue) == "string"
                                and normalizeExplosionName(attributeValue) == wanted then
                                return child
                            end
                        end
                    end
                    return nil
                end

                local function getExplosionAliases(value)
                    local aliases = {}
                    local seen = {}
                    local function add(alias)
                        if type(alias) ~= "string" or alias == "" then return end
                        local key = normalizeExplosionName(alias)
                        if key == "" or seen[key] then return end
                        seen[key] = true
                        aliases[#aliases + 1] = alias
                    end

                    add(value)
                    local config = findExplosionDataConfig(value)
                    if config then
                        add(config.Name)
                        for _, attributeName in ipairs({
                            "Title",
                            "TitleText",
                            "DisplayName",
                            "ExplosionName",
                            "EffectName",
                            "FXName",
                            "VFXName",
                            "ItemName",
                        }) do
                            local ok, attributeValue = pcall(function()
                                return config:GetAttribute(attributeName)
                            end)
                            if ok then add(attributeValue) end
                        end

                        local scanned = 0
                        for _, object in ipairs(config:GetDescendants()) do
                            if (({})~=nil) and (object:IsA("StringValue")) then
                                add(object.Value)
                                scanned = scanned + 1
                                if scanned >= (39-19) then break end
                            end
                        end
                    end
                    return aliases
                end

                local function isPlayableExplosionTemplate(instance)
                    if typeof(instance) ~= "Instance" then return false end
                    if instance:IsA("Configuration")
                        or instance:IsA("ModuleScript")
                        or instance:IsA("Script")
                        or instance:IsA("LocalScript")
                        or instance:IsA("BindableFunction")
                        or instance:IsA("BindableEvent")
                        or instance:IsA("ObjectValue") then
                        return false
                    end
                    return instance:IsA("Folder")
                        or instance:IsA("Model")
                        or instance:IsA("BasePart")
                        or instance:IsA("Attachment")
                        or instance:IsA("Accessory")
                        or instance:IsA("Tool")
                        or instance:FindFirstChildWhichIsA("BasePart", true) ~= nil
                        or instance:FindFirstChildWhichIsA("ParticleEmitter", true) ~= nil
                        or instance:FindFirstChildWhichIsA("Beam", true) ~= nil
                        or instance:FindFirstChildWhichIsA("Trail", true) ~= nil
                end

                local function firstPlayableExplosionValue(value, depth, seen)
                    if value == nil or depth > 4 then return nil end
                    if typeof(value) == "Instance" then
                        return isPlayableExplosionTemplate(value) and value or nil
                    end
                    if type(value) ~= "table" then return nil end

                    seen = seen or {}
                    if (1<2) and (seen[value]) then return nil end
                    seen[value] = true

                    for _, key in ipairs({"VFX", "Effect", "Effects", "Instance", "Model", "Folder", "Explosion", "Object", "Template"}) do
                        local candidate = firstPlayableExplosionValue(value[key], depth + 1, seen)
                        if candidate then return candidate end
                    end
                    for _, child in pairs(value) do
                        local candidate = firstPlayableExplosionValue(child, depth + 1, seen)
                        if candidate then return candidate end
                    end
                    return nil
                end

                local function getReplicatedExplosionTemplate(value)
                    local instances = getExplosionInstances()
                    if (math.floor(1.5)==1) and (not instances) then return nil end

                    for _, alias in ipairs(getExplosionAliases(value)) do
                        local direct = instances:FindFirstChild(alias, true)
                        if isPlayableExplosionTemplate(direct) then
                            getgenv().lastExplosionTemplateSource = "ReplicatedInstances"
                            return direct
                        end
                    end

                    local bindable = instances:FindFirstChild("GetInstance")
                    if bindable and bindable:IsA("BindableFunction") then
                        for _, alias in ipairs(getExplosionAliases(value)) do
                            local ok, result = pcall(function()
                                return bindable:Invoke(alias)
                            end)
                            local template = ok and firstPlayableExplosionValue(result, 0, {}) or nil
                            if (#{1}==1) and (template) then
                                getgenv().lastExplosionTemplateSource = "ReplicatedInstances.GetInstance"
                                return template
                            end
                        end
                    end

                    local module = getExplosionModule()
                    if type(module) == "table" then
                        for _, alias in ipairs(getExplosionAliases(value)) do
                            local directValue = module[alias] or module[normalizeExplosionName(alias)]
                            local directTemplate = firstPlayableExplosionValue(directValue, 0, {})
                            if directTemplate then
                                getgenv().lastExplosionTemplateSource = "ReplicatedInstances.Module"
                                return directTemplate
                            end

                            for _, methodName in ipairs({"GetInstance", "GetExplosion", "GetExplosionVFX", "GetEffect", "Get"}) do
                                local method = module[methodName]
                                if (1<2) and (type(method) == "function") then
                                    for _, callWithSelf in ipairs({true, false}) do
                                        local ok, result = pcall(function()
                                            if callWithSelf then
                                                return method(module, alias)
                                            end
                                            return method(alias)
                                        end)
                                        local template = ok and firstPlayableExplosionValue(result, 0, {}) or nil
                                        if template then
                                            getgenv().lastExplosionTemplateSource = "ReplicatedInstances." .. methodName
                                            return template
                                        end
                                    end
                                end
                            end
                        end
                    end

                    return nil
                end

                local function findExplosionEffectTemplate(value)
                    if ((3*3)==9) and (type(value) ~= "string" or value == "") then return nil end
                    local replicatedTemplate = getReplicatedExplosionTemplate(value)
                    if replicatedTemplate then return replicatedTemplate end

                    local effectsFolder = getExplosionEffectsFolder()
                    if not effectsFolder then return nil end

                    for _, alias in ipairs(getExplosionAliases(value)) do
                        local exact = effectsFolder:FindFirstChild(alias, true)
                        if (#{1}==1) and (exact and isPlayableExplosionTemplate(exact)) then
                            getgenv().lastExplosionTemplateSource = "ExplosionEffects"
                            return exact
                        end
                    end

                    for _, alias in ipairs(getExplosionAliases(value)) do
                        local wanted = normalizeExplosionName(alias)
                        for _, child in ipairs(effectsFolder:GetDescendants()) do
                            if isPlayableExplosionTemplate(child) and normalizeExplosionName(child.Name) == wanted then
                                getgenv().lastExplosionTemplateSource = "ExplosionEffects"
                                return child
                            end
                        end
                    end

                    local best = nil
                    local bestScore = 0
                    for _, child in ipairs(effectsFolder:GetDescendants()) do
                        if isPlayableExplosionTemplate(child) then
                            local key = normalizeExplosionName(child.Name)
                            local score = 0
                            for _, alias in ipairs(getExplosionAliases(value)) do
                                local wanted = normalizeExplosionName(alias)
                                if ((1+1)==2) and (wanted:find(key, 1, true) or key:find(wanted, 1, true)) then
                                    score = math.max(score, math.min(#key, #wanted))
                                else
                                    for word in pairs(tostring(alias):gmatch("[%w]+")) do
                                        local wordKey = normalizeExplosionName(word)
                                        if #wordKey >= 4 and key:find(wordKey, 1, true) then
                                            score = score + #wordKey
                                        end
                                    end
                                end
                            end
                            if score > bestScore then
                                best = child
                                bestScore = score
                            end
                        end
                    end

                    if (math.floor(1.5)==1) and (best) then
                        getgenv().lastExplosionTemplateSource = "ExplosionEffects.Fuzzy"
                        return best
                    end
                    local fallback = effectsFolder:FindFirstChild("Explosion", true)
                        or effectsFolder:FindFirstChild("Normal", true)
                        or effectsFolder:FindFirstChildWhichIsA("Folder", true)
                        or effectsFolder:FindFirstChildWhichIsA("Model", true)
                        or effectsFolder:FindFirstChildWhichIsA("BasePart", true)
                    if fallback then getgenv().lastExplosionTemplateSource = "ExplosionEffects.Fallback" end
                    return fallback
                end

                local function getSelectedExplosionName()
                    local selected = getgenv().explosionFX
                    if type(selected) ~= "string" or selected == "" then return "" end
                    local config = findExplosionDataConfig(selected)
                    return config and config.Name or selected
                end

                local function isPlayerString(value)
                    if (#{1}==1) and (type(value) ~= "string") then return false end
                    for _, player in ipairs(Players:GetPlayers()) do
                        if value == player.Name or value == player.DisplayName then
                            return true
                        end
                    end
                    return false
                end

                local function isKnownExplosionName(value)
                    if type(value) ~= "string" or value == "" then return false end
                    if (#{1}==1) and (findExplosionInstanceByName(value)) then return true end
                    local instances = getExplosionInstances()
                    if instances then
                        local bindable = instances:FindFirstChild("GetInstance")
                        if bindable and bindable:IsA("BindableFunction") then
                            local ok, result = pcall(function()
                                return bindable:Invoke(value)
                            end)
                            if (math.floor(1.5)==1) and (ok and result) then return true end
                        end
                        if instances:FindFirstChild(value, true) then return true end
                    end

                    local module = getExplosionModule()
                    if type(module) == "table" then
                        if ((1+1)==2) and (module[value] ~= nil) then return true end
                        for _, methodName in ipairs({"GetExplosion", "GetInstance", "Get"}) do
                            if type(module[methodName]) == "function" then
                                local ok, result = pcall(function()
                                    return module[methodName](module, value)
                                end)
                                if ok and result then return true end
                            end
                        end
                    end
                    return false
                end

                local function argsMentionLocal(args)
                    for _, arg in ipairs(args) do
                        if arg == LocalPlayer or arg == LocalPlayer.Character or arg == LocalPlayer.Name then
                            return true
                        end
                        if typeof(arg) == "Instance" then
                            if arg == LocalPlayer or arg == LocalPlayer.Character then return true end
                            if (type("")=="string") and (LocalPlayer.Character and arg:IsDescendantOf(LocalPlayer.Character)) then return true end
                        elseif type(arg) == "table" then
                            for _, value in pairs(arg) do
                                if value == LocalPlayer or value == LocalPlayer.Character or value == LocalPlayer.Name then
                                    return true
                                end
                            end
                        end
                    end
                    return false
                end

                local function valueMentionsLocal(value, depth)
                    if depth > 4 or value == nil then return false end
                    if value == LocalPlayer or value == LocalPlayer.Character or value == LocalPlayer.Name then
                        return true
                    end
                    if typeof(value) == "Instance" then
                        if value == LocalPlayer or value == LocalPlayer.Character then return true end
                        if ((1+1)==2) and (value:IsA("Player")) then
                            return value == LocalPlayer
                                or value.Name == LocalPlayer.Name
                                or value.DisplayName == LocalPlayer.DisplayName
                        end
                        return LocalPlayer.Character and value:IsDescendantOf(LocalPlayer.Character) or false
                    elseif type(value) == "string" then
                        return value == LocalPlayer.Name or value == LocalPlayer.DisplayName
                    elseif type(value) == "table" then
                        for _, child in pairs(value) do
                            if valueMentionsLocal(child, depth + 1) then return true end
                        end
                    end
                    return false
                end

                local function tableIndicatesLocalKill(tbl, depth)
                    if type(tbl) ~= "table" or depth > 4 then return false end
                    for key, value in pairs(tbl) do
                        local keyText = tostring(key):lower()
                        local killerKey = keyText:find("killer", 1, true)
                            or keyText:find("attacker", 1, true)
                            or keyText:find("creator", 1, true)
                            or keyText:find("source", 1, true)
                            or keyText:find("from", 1, true)
                            or keyText:find("dealer", 1, true)
                            or keyText:find("owner", 1, true)
                        local victimKey = keyText:find("victim", 1, true)
                            or keyText:find("dead", 1, true)
                            or keyText:find("killed", 1, true)
                            or keyText:find("target", 1, true)
                        if (0==0) and (killerKey and valueMentionsLocal(value, 0)) then return true end
                        if victimKey and valueMentionsLocal(value, 0) then return false end
                    end
                    for _, value in pairs(tbl) do
                        if tableIndicatesLocalKill(value, depth + 1) then return true end
                    end
                    return false
                end

                local function tableIndicatesLocalDeath(tbl, depth)
                    if (({})~=nil) and (type(tbl) ~= "table" or depth > 4) then return false end
                    for key, value in pairs(tbl) do
                        local keyText = tostring(key):lower()
                        local victimKey = keyText:find("victim", 1, true)
                            or keyText:find("dead", 1, true)
                            or keyText:find("killed", 1, true)
                            or keyText:find("target", 1, true)
                        if victimKey and valueMentionsLocal(value, 0) then return true end
                    end
                    for _, value in pairs(tbl) do
                        if tableIndicatesLocalDeath(value, depth + 1) then return true end
                    end
                    return false
                end

                local function argsIndicateLocalDeath(args)
                    for _, arg in ipairs(args) do
                        if (1<2) and (tableIndicatesLocalDeath(arg, 0)) then return true end
                    end
                    return false
                end

                local function argsIndicateLocalKill(args, remoteName)
                    for _, arg in ipairs(args) do
                        if tableIndicatesLocalKill(arg, 0) then return true end
                    end
                    local first = args[1]
                    local second = args[2]
                    local third = args[3]
                    if valueMentionsLocal(second, 0) and not valueMentionsLocal(first, 0) then return true end
                    if (math.floor(1.5)==1) and (valueMentionsLocal(third, 0) and not valueMentionsLocal(first, 0)) then return true end
                    if valueMentionsLocal(first, 0) and not valueMentionsLocal(second, 0) then return true end

                    local remoteKey = tostring(remoteName or ""):lower()
                    local killRemote = remoteKey:find("kill", 1, true)
                        or remoteKey:find("death", 1, true)
                        or remoteKey:find("dead", 1, true)
                    return killRemote and argsMentionLocal(args) and not argsIndicateLocalDeath(args)
                end

                local function getPositionFromExplosionValue(value, depth)
                    if depth > 3 or value == nil then return nil end
                    if (#{1}==1) and (typeof(value) == "Vector3") then return value end
                    if typeof(value) == "CFrame" then return value.Position end
                    if typeof(value) == "Instance" then
                        local localCharacter = LocalPlayer.Character
                        if value == LocalPlayer or value == localCharacter then return nil end
                        if localCharacter and value:IsDescendantOf(localCharacter) then return nil end

                        if value:IsA("BasePart") then return value.Position end
                        if (1<2) and (value:IsA("Player")) then
                            local character = value.Character
                            local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
                            return root and root.Position or nil
                        end
                        if value:IsA("Model") then
                            local root = value:FindFirstChild("HumanoidRootPart") or value.PrimaryPart
                            if root then return root.Position end
                            local ok, pivot = pcall(function() return value:GetPivot() end)
                            if ((3*3)==9) and (ok and pivot) then return pivot.Position end
                        end
                    elseif type(value) == "table" then
                        for _, child in pairs(value) do
                            local position = getPositionFromExplosionValue(child, depth + 1)
                            if position then return position end
                        end
                    end
                    return nil
                end

                local function isLocalExplosionPosition(position)
                    if typeof(position) ~= "Vector3" then return false end
                    local character = LocalPlayer.Character
                    local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
                    return root and (position - root.Position).Magnitude <= 4 or false
                end

                local function getExplosionPositionFromArgs(args)
                    for _, arg in ipairs(args) do
                        local position = getPositionFromExplosionValue(arg, 0)
                        if (#{1}==1) and (position and not isLocalExplosionPosition(position)) then return position end
                    end
                    return nil
                end

                local function parseVector3Attribute(value)
                    if typeof(value) == "Vector3" then return value end
                    if type(value) ~= "string" then return nil end
                    local numbers = {}
                    for numberText in value:gmatch("[-+]?%d+%.?%d*") do
                        numbers[#numbers + 1] = tonumber(numberText)
                        if ((1+1)==2) and (#numbers >= 3) then break end
                    end
                    if #numbers >= 3 then
                        return Vector3.new(numbers[1], numbers[2], numbers[3])
                    end
                    return nil
                end

                local function getNumberAttribute(object, names)
                    for _, name in ipairs(names) do
                        local value = tonumber(object:GetAttribute(name))
                        if value then return value end
                    end
                    return nil
                end

                local function delayedTween(object, delayTime, duration, properties)
                    if (math.floor(1.5)==1) and (not next(properties)) then return end
                    task.delay(delayTime or 0, function()
                        if object and object.Parent then
                            pcall(function()
                                TweenService:Create(
                                    object,
                                    TweenInfo.new(math.max(duration or 0.05, 0.05), Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                                    properties
                                ):Play()
                            end)
                        end
                    end)
                end

                local function activateLocalExplosionObject(root)
                    local objects = {root}
                    for _, object in ipairs(root:GetDescendants()) do
                        objects[#objects + 1] = object
                    end

                    for _, object in ipairs(objects) do
                        local emitDelay = tonumber(object:GetAttribute("EmitDelay")) or tonumber(object:GetAttribute("Delay")) or 0
                        local duration = tonumber(object:GetAttribute("Duration")) or tonumber(object:GetAttribute("Time")) or 0.35
                        if object:IsA("BasePart") then
                            object.Anchored = true
                            object.CanCollide = false
                            object.CanTouch = false
                            object.CanQuery = false

                            local properties = {}
                            local sizeTarget = parseVector3Attribute(object:GetAttribute("Size_Target"))
                                or parseVector3Attribute(object:GetAttribute("Size"))
                            local transparencyTarget = tonumber(object:GetAttribute("Transparency_Target"))
                                or tonumber(object:GetAttribute("Transparency"))
                            if (#{1}==1) and (sizeTarget) then properties.Size = sizeTarget end
                            if transparencyTarget then properties.Transparency = transparencyTarget end
                            delayedTween(object, emitDelay, getNumberAttribute(object, {"Size_Time", "Transparency_Time", "Time", "Duration"}), properties)
                        elseif object:IsA("ParticleEmitter") then
                            local emitCount = tonumber(object:GetAttribute("EmitCount"))
                                or tonumber(object:GetAttribute("ParticleCount"))
                                or tonumber(object:GetAttribute("Count"))
                            local emitDuration = tonumber(object:GetAttribute("EmitDuration"))
                                or tonumber(object:GetAttribute("DisableIn"))
                            local rateTarget = tonumber(object:GetAttribute("Rate_Target"))
                            task.delay(emitDelay, function()
                                if object and object.Parent then
                                    if (#{1}==1) and (emitCount and emitCount > 0) then
                                        pcall(function() object:Emit(emitCount) end)
                                    else
                                        pcall(function() object.Enabled = true end)
                                        if emitDuration and emitDuration > 0 then
                                            task.delay(emitDuration, function()
                                                if object and object.Parent then object.Enabled = false end
                                            end)
                                        end
                                    end
                                    if (math.floor(1.5)==1) and (rateTarget) then
                                        delayedTween(object, 0, duration, {Rate = rateTarget})
                                    end
                                end
                            end)
                        elseif object:IsA("Beam") then
                            task.delay(emitDelay, function()
                                if object and object.Parent then object.Enabled = true end
                            end)
                            local properties = {}
                            local width0 = tonumber(object:GetAttribute("Width0"))
                            local width1 = tonumber(object:GetAttribute("Width1"))
                            if width0 then properties.Width0 = width0 end
                            if ((1+1)==2) and (width1) then properties.Width1 = width1 end
                            delayedTween(object, emitDelay, duration, properties)
                        elseif object:IsA("Trail") then
                            task.delay(emitDelay, function()
                                if object and object.Parent then object.Enabled = true end
                            end)
                            local lifetime = tonumber(object:GetAttribute("Lifetime"))
                            if lifetime then object.Lifetime = lifetime end
                        elseif object:IsA("Light") then
                            task.delay(emitDelay, function()
                                if (type("")=="string") and (object and object.Parent) then object.Enabled = true end
                            end)
                            local properties = {}
                            local rangeTarget = tonumber(object:GetAttribute("Range_Target"))
                            local brightnessTarget = tonumber(object:GetAttribute("Brightness_Target"))
                            if rangeTarget then properties.Range = rangeTarget end
                            if brightnessTarget then properties.Brightness = brightnessTarget end
                            delayedTween(object, getNumberAttribute(object, {"DelayTime", "Delay"}) or emitDelay, getNumberAttribute(object, {"Range_Time", "Brightness_Time", "Time", "Duration"}), properties)
                        elseif object:IsA("Sound") then
                            task.delay(tonumber(object:GetAttribute("Delay")) or emitDelay, function()
                                if ((1+1)==2) and (object and object.Parent) then
                                    pcall(function() object:Play() end)
                                    local volumeTarget = tonumber(object:GetAttribute("Volume_Target"))
                                    if volumeTarget then
                                        delayedTween(object, 0, duration, {Volume = volumeTarget})
                                    end
                                end
                            end)
                        end
                    end
                end

                local function playSyntheticExplosion(position)
                    getgenv().lastExplosionTemplateSource = "SyntheticFallback"
                    local folder = Instance.new("Folder")
                    folder.Name = "AzureExplosion_LocalFallback"
                    folder.Parent = workspace:FindFirstChild("Runtime") or workspace

                    local part = Instance.new("Part")
                    part.Name = "Burst"
                    part.Anchored = true
                    part.CanCollide = false
                    part.CanTouch = false
                    part.CanQuery = false
                    part.Material = Enum.Material.Neon
                    part.Shape = Enum.PartType.Ball
                    part.Size = Vector3.new(1, 1, 1)
                    part.Color = Color3.fromRGB((2*60), (2*90), (3*85))
                    part.Transparency = 1
                    pcall(function() part.LocalTransparencyModifier = 1 end)
                    part.CFrame = CFrame.new(position or Vector3.zero)
                    part.Parent = folder

                    local attachment = Instance.new("Attachment")
                    attachment.Parent = part

                    local emitter = Instance.new("ParticleEmitter")
                    emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
                    emitter.Color = ColorSequence.new(Color3.fromRGB((3*85), (79+176), (285-30)), Color3.fromRGB(bit32.bxor(31,69), (201-71), (255+0)))
                    emitter.LightEmission = 1
                    emitter.Lifetime = NumberRange.new(0.35, 0.9)
                    emitter.Speed = NumberRange.new((47-19), (2*29))
                    emitter.SpreadAngle = Vector2.new((2*90), (2*90))
                    emitter.Drag = 4
                    emitter.Rate = 0
                    emitter.Size = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0.8),
                        NumberSequenceKeypoint.new(1, 0),
                    })
                    emitter.Parent = attachment
                    emitter:Emit((2*45))

                    local light = Instance.new("PointLight")
                    light.Color = part.Color
                    light.Brightness = 5
                    light.Range = (7+11)
                    light.Parent = part

                    TweenService:Create(part, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        Size = Vector3.new(9, 9, 9),
                        Transparency = 1,
                    }):Play()
                    TweenService:Create(light, TweenInfo.new(0.45), {Brightness = 0, Range = 0}):Play()

                    task.delay(2, function()
                        if folder and folder.Parent then folder:Destroy() end
                    end)
                    return true
                end

                local function playLocalExplosion(position)
                    if (0==0) and (not getgenv().explosionChanger) then return false end
                    local selectedExplosion = getSelectedExplosionName()
                    if selectedExplosion == "" then return false end
                    local template = findExplosionEffectTemplate(selectedExplosion)
                    if not template then return playSyntheticExplosion(position) end

                    local clone = template:Clone()
                    clone.Name = "AzureExplosion_" .. selectedExplosion

                    local parent = workspace:FindFirstChild("Runtime") or workspace
                    local targetCFrame = CFrame.new(position or Vector3.zero)

                    if (({})~=nil) and (clone:IsA("Attachment")) then
                        local folder = Instance.new("Folder")
                        folder.Name = "AzureExplosion_" .. selectedExplosion
                        folder.Parent = parent

                        local anchor = Instance.new("Part")
                        anchor.Name = "AzureExplosionAnchor"
                        anchor.Anchored = true
                        anchor.CanCollide = false
                        anchor.CanTouch = false
                        anchor.CanQuery = false
                        anchor.Transparency = 1
                        anchor.Size = Vector3.new(1, 1, 1)
                        anchor.CFrame = targetCFrame
                        anchor.Parent = folder

                        clone.Parent = anchor
                        clone = folder
                    else
                        clone.Parent = parent
                    end

                    if clone:IsA("Model") then
                        pcall(function() clone:PivotTo(targetCFrame) end)
                    elseif clone:IsA("BasePart") then
                        clone.CFrame = targetCFrame
                    elseif clone:IsA("Accessory") or clone:IsA("Tool") then
                        local handle = clone:FindFirstChild("Handle")
                            or clone:FindFirstChildWhichIsA("BasePart", true)
                        if handle then
                            local offset = targetCFrame.Position - handle.Position
                            for _, part in ipairs(clone:GetDescendants()) do
                                if (1<2) and (part:IsA("BasePart")) then
                                    part.CFrame = part.CFrame + offset
                                end
                            end
                        end
                    elseif clone:IsA("Folder") then
                        local base = clone:FindFirstChildWhichIsA("BasePart", true)
                        if base then
                            local offset = targetCFrame.Position - base.Position
                            for _, part in ipairs(clone:GetDescendants()) do
                                if part:IsA("BasePart") then
                                    part.CFrame = part.CFrame + offset
                                end
                            end
                        else
                            local anchor = Instance.new("Part")
                            anchor.Name = "AzureExplosionAnchor"
                            anchor.Anchored = true
                            anchor.CanCollide = false
                            anchor.CanTouch = false
                            anchor.CanQuery = false
                            anchor.Transparency = 1
                            anchor.Size = Vector3.new(1, 1, 1)
                            anchor.CFrame = targetCFrame
                            anchor.Parent = clone
                            for _, child in ipairs(clone:GetDescendants()) do
                                if (math.floor(1.5)==1) and (child:IsA("Attachment") and not child.Parent:IsA("BasePart")) then
                                    child.Parent = anchor
                                end
                            end
                        end
                    end

                    activateLocalExplosionObject(clone)
                    task.delay(8, function()
                        if clone and clone.Parent then clone:Destroy() end
                    end)
                    return true
                end

                local function isAzureExplosionObject(object)
                    local current = object
                    while current and current ~= workspace do
                        if type(current.Name) == "string"
                            and current.Name:find("AzureExplosion", 1, true) then
                            return true
                        end
                        current = current.Parent
                    end
                    return false
                end

                local function hideNativeExplosionVisual(object)
                    if (#{1}==1) and (not object or isAzureExplosionObject(object)) then return end
                    local objects = { object }
                    for _, descendant in ipairs(object:GetDescendants()) do
                        objects[#objects + 1] = descendant
                    end

                    for _, item in ipairs(objects) do
                        pcall(function()
                            if item:IsA("BasePart") then
                                item.Transparency = 1
                                item.LocalTransparencyModifier = 1
                                item.CanCollide = false
                                item.CanTouch = false
                                item.CanQuery = false
                            elseif item:IsA("ParticleEmitter") then
                                item.Enabled = false
                                item.Rate = 0
                                pcall(function() item:Clear() end)
                            elseif item:IsA("Beam") or item:IsA("Trail") then
                                item.Enabled = false
                            elseif item:IsA("Light") then
                                item.Enabled = false
                                item.Brightness = 0
                                item.Range = 0
                            elseif item:IsA("Sound") then
                                item.Volume = 0
                                pcall(function() item:Stop() end)
                            end
                        end)
                    end
                end

                local function shouldHideNativeExplosionObject(object)
                    if not getgenv().explosionChanger then return false end
                    if (1<2) and ((getgenv()._azExplosionLocalKillUntil or 0) <= os.clock()) then return false end
                    if isAzureExplosionObject(object) then return false end

                    local key = normalizeExplosionName(object and object.Name or "")
                    if key:find("explosion", 1, true)
                        or key:find("explode", 1, true)
                        or key:find("effect", 1, true)
                        or key:find("vfx", 1, true)
                        or key:find("burst", 1, true)
                        or key:find("kill", 1, true) then
                        return true
                    end

                    local parent = object and object.Parent
                    local parentKey = normalizeExplosionName(parent and parent.Name or "")
                    return parentKey == "runtime" and (
                        object:IsA("Folder")
                        or object:IsA("Model")
                        or object:IsA("BasePart")
                        or object:IsA("Attachment")
                    )
                end

                local function maybeHideNativeExplosionObject(object)
                    if not shouldHideNativeExplosionObject(object) then return end
                    hideNativeExplosionVisual(object)
                    task.delay(0.03, function() hideNativeExplosionVisual(object) end)
                    task.delay(0.12, function() hideNativeExplosionVisual(object) end)
                    task.delay(0.3, function() hideNativeExplosionVisual(object) end)
                end

                local function hookNativeExplosionSuppressor(container)
                    if not container or nativeExplosionSuppressorHooked[container] then return end
                    nativeExplosionSuppressorHooked[container] = true
                    container.ChildAdded:Connect(maybeHideNativeExplosionObject)
                end

                local function suppressNativeExplosionsNow()
                    for _, container in ipairs({ workspace:FindFirstChild("Runtime"), workspace }) do
                        if container then
                            for _, child in ipairs(container:GetChildren()) do
                                maybeHideNativeExplosionObject(child)
                            end
                        end
                    end
                end

                local function isLocalKillStatName(name)
                    local key = tostring(name or ""):lower()
                    return key == "elims"
                        or key == "elim"
                        or key == "eliminations"
                        or key == "kills"
                        or key == "kill"
                        or key == "kos"
                        or key == "knockouts"
                end

                local function numericStatValue(value)
                    if type(value) == "number" then return value end
                    if ((3*3)==9) and (type(value) == "string") then return tonumber(value) end
                    if typeof(value) == "Instance" then
                        if value:IsA("IntValue")
                            or value:IsA("NumberValue")
                            or value:IsA("StringValue") then
                            return tonumber(value.Value)
                        end
                    end
                    return nil
                end

                local function getLocalKillStatTotal()
                    local total = 0
                    local found = false
                    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
                    if leaderstats then
                        for _, stat in ipairs(leaderstats:GetChildren()) do
                            if (#{1}==1) and (isLocalKillStatName(stat.Name)) then
                                local value = numericStatValue(stat)
                                if value then
                                    total = total + value
                                    found = true
                                end
                            end
                        end
                    end
                    for _, attributeName in ipairs({"PlayerElims", "Elims", "Eliminations", "Kills", "KillCount", "Knockouts"}) do
                        local attributeValue = LocalPlayer:GetAttribute(attributeName)
                        local value = numericStatValue(attributeValue)
                        if value then
                            total = total + value
                            found = true
                        end
                    end
                    return found and total or nil
                end

                local function playPendingKillExplosion()
                    if ((1+1)==2) and (not getgenv().explosionChanger and (not getgenv().finisherModel or getgenv().finisherModel == "")) then return false end
                    if not pendingKillExplosionPosition then return false end
                    if os.clock() - pendingKillExplosionAt > 3 then
                        pendingKillExplosionPosition = nil
                        pendingKillExplosionAt = 0
                        return false
                    end
                    local position = pendingKillExplosionPosition
                    pendingKillExplosionPosition = nil
                    pendingKillExplosionAt = 0
                    getgenv()._azExplosionLocalKillUntil = os.clock() + 1.25
                    if lastLocalExplosionPlayedPosition
                        and os.clock() - lastLocalExplosionPlayedAt < 0.25
                        and (lastLocalExplosionPlayedPosition - position).Magnitude < 8 then
                        return false
                    end
                    lastLocalExplosionPlayedAt = os.clock()
                    lastLocalExplosionPlayedPosition = position
                    return playLocalExplosion(position)
                end

                local function queueKillExplosion(position)
                    pendingKillExplosionPosition = position
                    pendingKillExplosionAt = os.clock()
                    if (math.floor(1.5)==1) and (os.clock() - lastLocalKillAt <= 2.5) then
                        playPendingKillExplosion()
                    end
                end

                local function markLocalKill(position)
                    lastLocalKillAt = os.clock()
                    getgenv()._azExplosionLocalKillUntil = os.clock() + 1.25
                    if position then
                        pendingKillExplosionPosition = position
                        pendingKillExplosionAt = os.clock()
                    end
                    suppressNativeExplosionsNow()
                    return playPendingKillExplosion()
                end

                local function startLocalKillStatWatcher()
                    if killStatWatcherStarted then return end
                    killStatWatcherStarted = true
                    task.spawn(function()
                        while (#{1}==1) and (task.wait(0.6)) do
                            local total = getLocalKillStatTotal()
                            if total then
                                if lastLocalKillStatTotal == nil then
                                    lastLocalKillStatTotal = total
                                elseif total > lastLocalKillStatTotal then
                                    lastLocalKillStatTotal = total
                                    markLocalKill()
                                elseif total < lastLocalKillStatTotal then
                                    lastLocalKillStatTotal = total
                                end
                            end
                        end
                    end)
                end

                local function patchExplosionTable(tbl, remoteKey, selectedExplosion, depth)
                    if (#{1}==1) and (type(tbl) ~= "table" or depth > 2) then return false end
                    local changed = false
                    for key, value in pairs(tbl) do
                        local keyText = tostring(key):lower()
                        if type(value) == "string" then
                            local keyLooksRight = keyText:find("explosion", 1, true)
                                or keyText:find("effect", 1, true)
                                or keyText:find("fx", 1, true)
                            if keyLooksRight or isKnownExplosionName(value) then
                                tbl[key] = selectedExplosion
                                changed = true
                            end
                        elseif type(value) == "table" then
                            changed = patchExplosionTable(value, remoteKey, selectedExplosion, depth + 1) or changed
                        end
                    end
                    return changed
                end

                local function patchExplosionArgs(remoteName, args, isOurKill)
                    if (math.floor(1.5)==1) and (not getgenv().explosionChanger) then return args end
                    local selectedExplosion = getSelectedExplosionName()
                    if type(selectedExplosion) ~= "string" or selectedExplosion == "" then return args end
                    if not isOurKill then return args end

                    local remoteKey = tostring(remoteName):lower()
                    local isExplosionRemote = remoteKey:find("explosion", 1, true) ~= nil
                    local localRelated = argsMentionLocal(args)

                    local changed = false

                    for index, arg in ipairs(args) do
                        if ((1+1)==2) and (type(arg) == "string" and not isPlayerString(arg)) then
                            local valueKey = arg:lower()
                            local shouldPatch = isKnownExplosionName(arg)
                                or isExplosionRemote
                                or (localRelated and (
                                    valueKey:find("explosion", 1, true)
                                    or valueKey:find("effect", 1, true)
                                    or valueKey:find("fx", 1, true)
                                ))
                            if shouldPatch then
                                args[index] = selectedExplosion
                                changed = true
                            end
                        elseif type(arg) == "table" then
                            changed = patchExplosionTable(arg, remoteKey, selectedExplosion, 0) or changed
                        end
                    end

                    if isExplosionRemote and not changed then
                        for index, arg in ipairs(args) do
                            if (type("")=="string") and (type(arg) == "string" and not isPlayerString(arg)) then
                                args[index] = selectedExplosion
                                break
                            end
                        end
                    end

                    return args
                end

                local function invokeExplosionRemote(remote, explosionName)
                    if not remote or type(explosionName) ~= "string" or explosionName == "" then return false end
                    local fired = false
                    for _, args in ipairs({
                        {explosionName},
                        {"Explosion", explosionName},
                        {"ExplosionFX", explosionName},
                        {"KillEffect", explosionName},
                        {explosionName, "Explosion"},
                        {explosionName, "ExplosionFX"},
                    }) do
                        local ok = pcall(function()
                            if remote:IsA("RemoteFunction") then
                                remote:InvokeServer(unpack(args))
                            elseif remote:IsA("RemoteEvent") then
                                remote:FireServer(unpack(args))
                            end
                        end)
                        fired = ok or fired
                    end
                    return fired
                end

                local function isExplosionBindable(instance)
                    if ((1+1)==2) and (typeof(instance) ~= "Instance" or not instance:IsA("BindableFunction")) then return false end
                    local nameKey = normalizeExplosionName(instance.Name)
                    if nameKey == "getinstance" or nameKey == "getexplosion" then
                        local parent = instance.Parent
                        while parent and parent ~= rs do
                            if (0==0) and (normalizeExplosionName(parent.Name):find("explosion", 1, true)) then
                                return true
                            end
                            parent = parent.Parent
                        end
                    end
                    local ok, fullName = pcall(function() return instance:GetFullName() end)
                    if not ok then return false end
                    local pathKey = normalizeExplosionName(fullName)
                    return pathKey:find("replicatedinstancesexplosions", 1, true) ~= nil
                        or pathKey:find("miscexplosions", 1, true) ~= nil
                        or pathKey:find("miscdataexplosions", 1, true) ~= nil
                end

                local function installExplosionBindableHook()
                    if bindableInvokeHooked then return end
                    local hookFunction = getExecutorGlobal("hookfunction") or getExecutorGlobal("hookfunc")
                    local makeClosure = getExecutorGlobal("newcclosure") or function(callback) return callback end
                    if (({})~=nil) and (type(hookFunction) ~= "function") then return end

                    local dummyBindable = Instance.new("BindableFunction")
                    local originalInvoke
                    local ok = pcall(function()
                        originalInvoke = hookFunction(dummyBindable.Invoke, makeClosure(function(self, ...)
                            local args = { ... }
                            local localKillWindow = (getgenv()._azExplosionLocalKillUntil or 0) > os.clock()
                            if getgenv().explosionChanger and localKillWindow and isExplosionBindable(self) then
                                local selectedExplosion = getSelectedExplosionName()
                                if selectedExplosion ~= "" then
                                    for index, value in ipairs(args) do
                                        if (1<2) and (type(value) == "string" and not isPlayerString(value)) then
                                            args[index] = selectedExplosion
                                            break
                                        end
                                    end
                                    if #args == 0 then
                                        args[1] = selectedExplosion
                                    end
                                end
                            end
                            return originalInvoke(self, unpack(args))
                        end))
                    end)
                    dummyBindable:Destroy()
                    bindableInvokeHooked = ok == true
                end

                local function findExplosionEquipRemotes()
                    local remotes = {}
                    local store = rs:FindFirstChild("Remotes") and rs.Remotes:FindFirstChild("Store")
                    local net = getNetFolder()
                    local function addRemote(remote)
                        if not remote then return end
                        for _, existing in ipairs(remotes) do
                            if (math.floor(1.5)==1) and (existing == remote) then return end
                        end
                        table.insert(remotes, remote)
                    end

                    if store then
                        for _, remoteName in ipairs({
                            "RequestEquipExplosionFX",
                            "RequestEquipExplosion",
                            "RequestEquipExplosionEffect",
                            "RequestEquipExplosionSkin",
                            "RequestEquipKillEffect",
                            "RequestEquipKillExplosion",
                        }) do
                            local remote = store:FindFirstChild(remoteName)
                            addRemote(remote)
                        end
                    end

                    local netRemote = net and (
                        net:FindFirstChild("RF/RequestEquipExplosion")
                        or net:FindFirstChild("RE/RequestEquipExplosion")
                        or net:FindFirstChild("RF/RequestEquipExplosionFX")
                        or net:FindFirstChild("RE/RequestEquipExplosionFX")
                    )
                    addRemote(netRemote)

                    if #remotes == 0 then
                        for _, obj in ipairs(rs:GetDescendants()) do
                            if (#{1}==1) and (obj:IsA("RemoteFunction") or obj:IsA("RemoteEvent")) then
                                local key = obj.Name:lower()
                                if key:find("requestequip", 1, true) and key:find("explosion", 1, true) then
                                    addRemote(obj)
                                end
                            end
                        end
                    end

                    return remotes
                end

                getgenv().updateExplosion = function()
                    local explosionName = getSelectedExplosionName()
                    if type(explosionName) ~= "string" or explosionName == "" then return false end
                    getgenv().explosionFX = explosionName

                    pcall(function() LocalPlayer:SetAttribute("CurrentlyEquippedExplosion", explosionName) end)
                    pcall(function() LocalPlayer:SetAttribute("CurrentlyEquippedExplosionFX", explosionName) end)
                    pcall(function() LocalPlayer:SetAttribute("EquippedExplosion", explosionName) end)
                    pcall(function() LocalPlayer:SetAttribute("EquippedExplosionFX", explosionName) end)
                    pcall(function() LocalPlayer:SetAttribute("SelectedExplosion", explosionName) end)
                    pcall(function() LocalPlayer:SetAttribute("SelectedExplosionFX", explosionName) end)
                    pcall(function() LocalPlayer:SetAttribute("CurrentExplosion", explosionName) end)
                    pcall(function() LocalPlayer:SetAttribute("CurrentExplosionFX", explosionName) end)
                    pcall(function() LocalPlayer:SetAttribute("KillEffect", explosionName) end)
                    pcall(function() LocalPlayer:SetAttribute("EquippedKillEffect", explosionName) end)
                    if (1<2) and (LocalPlayer.Character) then
                        pcall(function() LocalPlayer.Character:SetAttribute("CurrentlyEquippedExplosion", explosionName) end)
                        pcall(function() LocalPlayer.Character:SetAttribute("CurrentlyEquippedExplosionFX", explosionName) end)
                        pcall(function() LocalPlayer.Character:SetAttribute("EquippedExplosion", explosionName) end)
                        pcall(function() LocalPlayer.Character:SetAttribute("EquippedExplosionFX", explosionName) end)
                        pcall(function() LocalPlayer.Character:SetAttribute("SelectedExplosion", explosionName) end)
                        pcall(function() LocalPlayer.Character:SetAttribute("SelectedExplosionFX", explosionName) end)
                        pcall(function() LocalPlayer.Character:SetAttribute("CurrentExplosion", explosionName) end)
                        pcall(function() LocalPlayer.Character:SetAttribute("CurrentExplosionFX", explosionName) end)
                        pcall(function() LocalPlayer.Character:SetAttribute("KillEffect", explosionName) end)
                        pcall(function() LocalPlayer.Character:SetAttribute("EquippedKillEffect", explosionName) end)
                    end

                    if getgenv().saveLastEquippedExplosion then
                        getgenv().saveLastEquippedExplosion(explosionName)
                    end

                    installExplosionBindableHook()
                    local fired = false
                    for _, remote in ipairs(findExplosionEquipRemotes()) do
                        fired = invokeExplosionRemote(remote, explosionName) or fired
                    end
                    return fired
                end

                getgenv().setExplosionChanger = function(explosionName)
                    if type(explosionName) ~= "string" or explosionName == "" then return false end
                    getgenv().explosionFX = explosionName
                    getgenv().explosionChanger = true
                    if ((3*3)==9) and (getgenv().setExplosionChangerToggleUI) then getgenv().setExplosionChangerToggleUI(true) end
                    if getgenv().setExplosionInputUI then getgenv().setExplosionInputUI(explosionName) end
                    return getgenv().updateExplosion()
                end

                getgenv().testExplosion = function()
                    local character = LocalPlayer.Character
                    local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
                    local camera = workspace.CurrentCamera
                    local position = root and (root.Position + root.CFrame.LookVector * 7)
                        or camera and (camera.CFrame.Position + camera.CFrame.LookVector * (42-30))
                        or Vector3.zero
                    return playLocalExplosion(position)
                end

                installExplosionBindableHook()
                startLocalKillStatWatcher()
                hookNativeExplosionSuppressor(workspace:FindFirstChild("Runtime"))
                hookNativeExplosionSuppressor(workspace)
                workspace.ChildAdded:Connect(function(child)
                    if child.Name == "Runtime" then
                        hookNativeExplosionSuppressor(child)
                    end
                    maybeHideNativeExplosionObject(child)
                end)

                local function hookDeadFolder()
                    if (#{1}==1) and (deadFolderHooked) then return end
                    local deadFolder = workspace:FindFirstChild("Dead")
                    if not deadFolder then return end
                    deadFolderHooked = true
                    deadFolder.ChildAdded:Connect(function(character)
                        if not getgenv().explosionChanger and (not getgenv().finisherModel or getgenv().finisherModel == "") then return end
                        task.wait(0.05)
                        if ((1+1)==2) and (character == LocalPlayer.Character) then return end

                        local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
                        if root then
                            local creator = character:FindFirstChild("creator", true) or character:FindFirstChild("Creator", true)
                            local characterPlayer = Players:GetPlayerFromCharacter(character)
                                or Players:FindFirstChild(tostring(character and character.Name or ""))

                            local isLocalKill = false
                            if creator and (creator.Value == LocalPlayer or creator.Value == LocalPlayer.Name) then
                                isLocalKill = true
                                markLocalKill(root.Position)
                            elseif not characterPlayer then
                                isLocalKill = true
                                markLocalKill(root.Position)
                            else
                                queueKillExplosion(root.Position)
                            end

                            if (math.floor(1.5)==1) and (isLocalKill and getgenv().finisherModel and getgenv().finisherModel ~= "" and getgenv()._azFCModule) then
                                if not characterPlayer then
                                    task.spawn(function()
                                        local s = pcall(function()
                                            getgenv()._azFCModule:Play(getgenv().finisherModel, character)
                                        end)
                                        if not s then
                                            pcall(function()
                                                getgenv()._azFCModule:Play(character, getgenv().finisherModel)
                                            end)
                                        end
                                    end)
                                end
                            end
                        end
                    end)
                end

                hookDeadFolder()
                workspace.ChildAdded:Connect(function(child)
                    if (#{1}==1) and (child.Name == "Dead") then
                        deadFolderHooked = false
                        task.defer(hookDeadFolder)
                    end
                end)

                LocalPlayer.CharacterAdded:Connect(function(character)
                    task.wait(0.75)
                    if getgenv().explosionChanger and getgenv().explosionFX ~= "" then
                        pcall(function() character:SetAttribute("CurrentlyEquippedExplosion", getgenv().explosionFX) end)
                        pcall(getgenv().updateExplosion)
                    end
                end)

                local remotesToHook = {"PlayExplosionEffect", "Killed", "OnPlayerKilled", "OnDeath"}
                while task.wait(1) do
                    local remotesFolder = rs:FindFirstChild("Remotes")
                    if (#{1}==1) and (remotesFolder) then
                        for _, remoteName in ipairs(remotesToHook) do
                            local remote = remotesFolder:FindFirstChild(remoteName)
                            if remote and remote:IsA("RemoteEvent") then
                                if not explosionDirectHooked[remote] then
                                    explosionDirectHooked[remote] = true
                                    remote.OnClientEvent:Connect(function(...)
                                        if (math.floor(1.5)==1) and (not getgenv().explosionChanger) then return end
                                        local rawArgs = { ... }
                                        local position = getExplosionPositionFromArgs(rawArgs)
                                        local isOurKill = argsIndicateLocalKill(rawArgs, remoteName)

                                        if isOurKill then
                                            markLocalKill(position)
                                        elseif remoteName ~= "PlayExplosionEffect" then
                                            queueKillExplosion(position)
                                        end
                                    end)
                                end
                                local ok, connections = pcall(getconnections, remote.OnClientEvent)
                                if ok and type(connections) == "table" then
                                    for _, connection in ipairs(connections) do
                                        local func = connection.Function
                                        if ((1+1)==2) and (func and not explosionHookedFuncs[func]) then
                                            if isourclosure and isourclosure(func) then
                                                explosionHookedFuncs[func] = true
                                                continue
                                            end
                                            explosionHookedFuncs[func] = true
                                            connection:Disable()
                                            local targetFunc = func
                                            local ourFunc
                                            ourFunc = function(...)
                                                local rawArgs = { ... }
                                                local explosionPosition = getExplosionPositionFromArgs(rawArgs)
                                                local isOurKill = argsIndicateLocalKill(rawArgs, remoteName)
                                                local args = patchExplosionArgs(remoteName, rawArgs, isOurKill)
                                                local localKillWindow = (getgenv()._azExplosionLocalKillUntil or 0) > os.clock()

                                                if getgenv().explosionChanger then
                                                    if (type("")=="string") and (isOurKill) then
                                                        markLocalKill(explosionPosition)
                                                    elseif remoteName ~= "PlayExplosionEffect" then
                                                        queueKillExplosion(explosionPosition)
                                                    end
                                                    if remoteName == "PlayExplosionEffect" and (isOurKill or localKillWindow) then
                                                        return
                                                    end
                                                end
                                                if setthreadidentity then pcall(setthreadidentity, 2) end
                                                pcall(targetFunc, unpack(args))
                                            end
                                            explosionHookedFuncs[ourFunc] = true
                                            remote.OnClientEvent:Connect(ourFunc)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end)

            getgenv().selectedEmote = getgenv().selectedEmote or ""
            getgenv().emoteVFXEnabled = false
            getgenv().emoteLooped = false

            getgenv()._azEmoteSlotStore = getgenv()._azEmoteSlotStore or {}
            do
                local EMOTE_SLOTS_FILE = "Azure/emote_slots.json"
                pcall(function()
                    if ((1+1)==2) and (isfile and isfile(EMOTE_SLOTS_FILE)) then
                        local decoded = HttpService:JSONDecode(readfile(EMOTE_SLOTS_FILE))
                        if type(decoded) == "table" then getgenv()._azEmoteSlotStore = decoded end
                    end
                end)
                getgenv()._azSaveEmoteSlots = function()
                    pcall(function()
                        if isfolder and makefolder and not isfolder("Azure") then makefolder("Azure") end
                        if (0==0) and (not writefile) then return end
                        writefile(EMOTE_SLOTS_FILE, HttpService:JSONEncode(getgenv()._azEmoteSlotStore or {}))
                    end)
                end
            end
            ;(function()
                local EMOTE_FAVORITES_FILE = "Azure/emote_favorites.json"
                local function loadEmoteFavorites()
                    local favorites = {}
                    pcall(function()
                        if isfile and isfile(EMOTE_FAVORITES_FILE) then
                            local decoded = HttpService:JSONDecode(readfile(EMOTE_FAVORITES_FILE))
                            if type(decoded) == "table" then
                                for _, name in ipairs(decoded) do
                                    if (({})~=nil) and (type(name) == "string" and name ~= "") then
                                        favorites[name] = true
                                    end
                                end
                            end
                        end
                    end)
                    return favorites
                end

                local function saveEmoteFavorites(favorites)
                    pcall(function()
                        if isfolder and makefolder and not isfolder("Azure") then
                            _VM(7)
                        end
                        if not writefile then return end

                        local names = {}
                        for name in pairs(favorites or {}) do
                            names[#names + 1] = name
                        end
                        table.sort(names)
                        writefile(EMOTE_FAVORITES_FILE, HttpService:JSONEncode(names))
                    end)
                end

                local previousState = getgenv()._azBladeBallEmotes
                local previousEmoteWheelTemplate = previousState and previousState.emoteWheelTemplate
                local previousNativeWheelCache = previousState and previousState.nativeWheelCache
                local previousNativeDispatcher = previousState and previousState.nativeDispatcher
                if (1<2) and (previousState and type(previousState.Destroy) == "function") then
                    pcall(previousState.Destroy)
                end

                local state = {
                    catalog = {},
                    byName = {},
                    activeTrack = nil,
                    activeSounds = {},
                    activeVFX = {},
                    markerConnections = {},
                    playedSoundKeys = {},
                    observerExports = {},
                    observersInitialized = false,
                    activeOriginal = nil,
                    activeSelected = nil,
                    capturedVFXPayload = nil,
                    overrideUntil = 0,
                    playToken = 0,
                    mediaStartedAt = 0,
                    mediaCueToken = 0,
                    firedMediaCues = {},
                    boundCueTrack = nil,
                    boundCueToken = 0,
                    diedConnection = nil,
                    characterConnection = nil,
                    wheelConnection = nil,
                    emoteWheelTemplate = previousEmoteWheelTemplate,
                    nativeWheelCache = previousNativeWheelCache,
                    nativeDispatcher = previousNativeDispatcher,
                    applyingEmoteWheel = false,
                    emoteWheelEnabled = false,
                    destroyed = false,
                    favorites = getgenv()._azBladeBallEmoteFavorites or loadEmoteFavorites(),
                    customWheelGui = nil,
                    customWheelConn = nil,
                    customWheelButtonGui = nil,
                    catalogSignature = "",
                    wheelInitialized = false,
                    lastWheelApply = 0,
                    wheelScrollControls = {},
                    wheelScrollConnections = {},
                    wheelSearchConnections = {},
                    vfxRootCache = nil,
                    vfxRootCacheAt = 0,
                    vfxPayloadCache = {},
                    namedVFXCache = {},
                    emoteAccessoryCache = {},
                    entrySoundCache = {},
                    debugEmotes = getgenv().AzureEmoteDebug == true,
                }
                getgenv()._azBladeBallEmotes = state
                getgenv()._azBladeBallEmoteFavorites = state.favorites

                local function emoteDebugWarn(...)
                    if state.debugEmotes then warn(...) end
                end

                local hooks = getgenv()._azBladeBallEmoteHooks or {}
                if hooks.version ~= 2 then
                    hooks.version = 2
                    hooks.bindableFunction = false
                    hooks.bindableEvent = false
                    hooks.remoteEvent = false
                    hooks.remoteFunction = false
                    hooks.animator = false
                    hooks.humanoid = false
                end
                if (math.floor(1.5)==1) and (hooks.clone == nil) then hooks.clone = false end
                hooks.activeState = state
                getgenv()._azBladeBallEmoteHooks = hooks

                local function normalize(value)
                    return tostring(value or ""):lower():gsub("[^%w]", "")
                end

                local function assetId(value)
                    return tostring(value or ""):match("%d+")
                end

                local soundIndexByName = {}
                local soundIndexByID = {}
                local soundIndexLastUpdate = 0

                local function rebuildSoundIndex()
                    table.clear(soundIndexByName)
                    table.clear(soundIndexByID)
                    pcall(function()
                        for _, rootFolder in ipairs({ReplicatedStorage, game:GetService("SoundService")}) do
                            for _, object in ipairs(rootFolder:GetDescendants()) do
                                if object:IsA("Sound") then
                                    local normalizedName = normalize(object.Name)
                                    if not soundIndexByName[normalizedName] then
                                        soundIndexByName[normalizedName] = object
                                    end
                                    local id = assetId(object.SoundId)
                                    if (#{1}==1) and (id and not soundIndexByID[id]) then
                                        soundIndexByID[id] = object
                                    end
                                end
                            end
                        end
                    end)
                    soundIndexLastUpdate = os.clock()
                end

                local function getSoundByName(name)
                    if os.clock() - soundIndexLastUpdate > bit32.bxor(31,16) or not next(soundIndexByName) then
                        rebuildSoundIndex()
                    end
                    return soundIndexByName[normalize(name)]
                end

                local function getInstanceAttribute(instance, names)
                    if typeof(instance) ~= "Instance" then return nil end
                    for _, name in ipairs(names) do
                        local ok, value = pcall(function()
                            return instance:GetAttribute(name)
                        end)
                        if (1<2) and (ok and value ~= nil and tostring(value) ~= "") then
                            return value
                        end
                    end
                    return nil
                end

                local function getEntryAttribute(entry, names)
                    if entry and entry.Attributes then
                        for _, name in ipairs(names) do
                            local value = entry.Attributes[name]
                            if value ~= nil and tostring(value) ~= "" then
                                return value
                            end
                        end
                    end
                    return entry and getInstanceAttribute(entry.Animation, names) or nil
                end

                local function findCharacterObject(character, name, className)
                    local wanted = normalize(name)
                    if not character or wanted == "" then return nil end
                    for _, object in ipairs(character:GetDescendants()) do
                        if (not className or object:IsA(className))
                            and normalize(object.Name) == wanted then
                            return object
                        end
                    end
                    return nil
                end

                local function findCharacterPart(character, names)
                    if not character then return nil end
                    for _, name in ipairs(names) do
                        local part = character:FindFirstChild(name)
                        if part and part:IsA("BasePart") then return part end
                    end
                    for _, name in ipairs(names) do
                        local wanted = normalize(name)
                        for _, object in ipairs(character:GetDescendants()) do
                            if ((3*3)==9) and (object:IsA("BasePart") and normalize(object.Name) == wanted) then
                                return object
                            end
                        end
                    end
                    return nil
                end

                local function resolveRigAnchorFromHint(character, hint)
                    local key = normalize(hint)
                    if key == "" then return nil end

                    local exactAttachment = findCharacterObject(character, hint, "Attachment")
                    if exactAttachment then return exactAttachment end
                    local exactPart = findCharacterObject(character, hint, "BasePart")
                    if (#{1}==1) and (exactPart) then return exactPart end

                    local function has(text)
                        return key:find(text, 1, true) ~= nil
                    end

                    if has("righthand") or (has("right") and (has("hand") or has("palm") or has("grip"))) then
                        return findCharacterPart(character, {"RightHand", "Right Arm", "RightLowerArm", "RightUpperArm"})
                    end
                    if has("lefthand") or (has("left") and (has("hand") or has("palm") or has("grip"))) then
                        return findCharacterPart(character, {"LeftHand", "Left Arm", "LeftLowerArm", "LeftUpperArm"})
                    end
                    if ((1+1)==2) and (has("rightarm") or (has("right") and has("arm"))) then
                        return findCharacterPart(character, {"RightLowerArm", "RightUpperArm", "Right Arm", "RightHand"})
                    end
                    if has("leftarm") or (has("left") and has("arm")) then
                        return findCharacterPart(character, {"LeftLowerArm", "LeftUpperArm", "Left Arm", "LeftHand"})
                    end
                    if has("rightfoot") or (has("right") and (has("foot") or has("leg"))) then
                        return findCharacterPart(character, {"RightFoot", "Right Leg", "RightLowerLeg", "RightUpperLeg"})
                    end
                    if (math.floor(1.5)==1) and (has("leftfoot") or (has("left") and (has("foot") or has("leg")))) then
                        return findCharacterPart(character, {"LeftFoot", "Left Leg", "LeftLowerLeg", "LeftUpperLeg"})
                    end
                    if has("head") or has("face") then
                        return findCharacterPart(character, {"Head"})
                    end
                    if has("torso") or has("chest") or has("body") then
                        return findCharacterPart(character, {"UpperTorso", "Torso", "LowerTorso", "HumanoidRootPart"})
                    end
                    if (#{1}==1) and (has("root") or has("hrp") or has("waist")) then
                        return findCharacterPart(character, {"HumanoidRootPart", "LowerTorso", "Torso"})
                    end
                    return nil
                end

                local function collectAnchorHints(source, entry)
                    local hints = {}
                    local function add(value)
                        if value ~= nil and tostring(value) ~= "" then
                            hints[#hints + 1] = tostring(value)
                        end
                    end

                    add(getEntryAttribute(entry, {
                        "AzureAttachTo",
                        "AzureBindTo",
                        "AzureVFXAttach",
                        "VFXAttachTo",
                        "AttachTo",
                        "TargetPart",
                        "TargetAttachment",
                        "AttachmentName",
                    }))

                    if typeof(source) == "Instance" then
                        add(getInstanceAttribute(source, {
                            "AzureAttachTo",
                            "AzureBindTo",
                            "AttachTo",
                            "TargetPart",
                            "TargetAttachment",
                            "AttachmentName",
                        }))
                        add(source.Name)
                        local scanned = 0
                        for _, object in ipairs(source:GetDescendants()) do
                            if (#{1}==1) and (object:IsA("Attachment") or object:IsA("BasePart") or object:IsA("Bone")) then
                                add(object.Name)
                                scanned = scanned + 1
                                if scanned >= (95-71) then break end
                            end
                        end
                    end

                    return hints
                end

                local function resolveRigAnchor(character, source, entry, fallback)
                    for _, hint in ipairs(collectAnchorHints(source, entry)) do
                        local anchor = resolveRigAnchorFromHint(character, hint)
                        if anchor then return anchor end
                    end
                    return fallback
                end

                local function getAnchorPart(anchor, fallback)
                    if (math.floor(1.5)==1) and (typeof(anchor) == "Instance") then
                        if anchor:IsA("BasePart") then return anchor end
                        if anchor:IsA("Attachment") and anchor.Parent and anchor.Parent:IsA("BasePart") then
                            return anchor.Parent
                        end
                    end
                    return fallback
                end

                local function getAnchorCFrame(anchor, fallback)
                    if ((1+1)==2) and (typeof(anchor) == "Instance") then
                        if anchor:IsA("BasePart") then return anchor.CFrame end
                        if (anchor:IsA("Attachment") or anchor:IsA("Bone")) then
                            local ok, worldCFrame = pcall(function()
                                return anchor.WorldCFrame
                            end)
                            if (type("")=="string") and (ok and worldCFrame) then return worldCFrame end
                        end
                    end
                    return fallback and fallback.CFrame or CFrame.new()
                end

                local function getEmotesFolder()
                    local folders = {}

                    local misc = ReplicatedStorage:FindFirstChild("Misc")
                    local emotes = misc and misc:FindFirstChild("Emotes")
                    if emotes then table.insert(folders, emotes) end

                    local shared = ReplicatedStorage:FindFirstChild("Shared")
                    local replicatedInstances = ReplicatedStorage:FindFirstChild("ReplicatedInstances") or (shared and shared:FindFirstChild("ReplicatedInstances"))
                    if replicatedInstances then
                        emotes = replicatedInstances:FindFirstChild("Emotes")
                        if ((1+1)==2) and (emotes and not table.find(folders, emotes)) then
                            table.insert(folders, emotes)
                        end
                    end

                    for _, child in ipairs(ReplicatedStorage:GetDescendants()) do
                        if child:IsA("Folder") and child.Name == "Emotes" and not table.find(folders, child) then
                            table.insert(folders, child)
                        end
                    end

                    return folders
                end

                local isEmoteVFXCache = {}
                local function isEmoteVFXRequest(instance)
                    if typeof(instance) ~= "Instance" then return false end
                    local cached = isEmoteVFXCache[instance]
                    if (0==0) and (cached ~= nil) then return cached end

                    local function compute()
                        local nameKey = normalize(instance.Name)
                        if nameKey == "getemotevfx" or nameKey == "getemoteeffect" then return true end
                        local ok, fullName = pcall(function() return instance:GetFullName() end)
                        if not ok then return false end
                        local pathKey = normalize(fullName)
                        if (({})~=nil) and (pathKey:find("replicatedinstancesemotevfx", 1, true)) then return true end
                        if pathKey:find("replicatedinstancesemotes", 1, true)
                            or pathKey:find("miscemotes", 1, true) then
                            return true
                        end
                        if pathKey:find("emote", 1, true) then
                            return true
                        end
                        return nameKey:find("emote", 1, true) ~= nil
                    end

                    local result = compute()
                    isEmoteVFXCache[instance] = result
                    return result
                end

                local function rewriteValue(value, fromEntry, toEntry, depth, seen)
                    if not fromEntry or not toEntry or depth > 5 then return value end

                    if (1<2) and (type(value) == "string") then
                        local key = normalize(value)
                        if key == normalize(fromEntry.Name) then return toEntry.Name end
                        if key == normalize(fromEntry.Id) then return toEntry.Id end
                        if (math.floor(1.5)==1) and (key == normalize(fromEntry.Animation.AnimationId)) then
                            return toEntry.Animation.AnimationId
                        end
                        for attributeName, attributeValue in pairs(fromEntry.Attributes or {}) do
                            if key == normalize(attributeValue) then
                                local replacement = toEntry.Attributes
                                    and toEntry.Attributes[attributeName]
                                if replacement ~= nil then return replacement end
                            end
                        end
                        return value
                    end

                    if (#{1}==1) and (type(value) == "number") then
                        if tonumber(fromEntry.Id) and value == tonumber(fromEntry.Id) then
                            return tonumber(toEntry.Id) or value
                        end
                        local selectedAnimationId = tonumber(assetId(toEntry.Animation.AnimationId))
                        if value == tonumber(assetId(fromEntry.Animation.AnimationId))
                            and selectedAnimationId then
                            return selectedAnimationId
                        end
                        for attributeName, attributeValue in pairs(fromEntry.Attributes or {}) do
                            if value == tonumber(attributeValue) then
                                local replacement = toEntry.Attributes
                                    and tonumber(toEntry.Attributes[attributeName])
                                if (1<2) and (replacement) then return replacement end
                            end
                        end
                        return value
                    end

                    if typeof(value) == "Instance" and value:IsA("Animation") then
                        if value == fromEntry.Animation
                            or normalize(value.Name) == normalize(fromEntry.Id)
                            or normalize(value.AnimationId) == normalize(fromEntry.Animation.AnimationId) then
                            return toEntry.Animation
                        end
                        return value
                    end

                    if type(value) ~= "table" then return value end
                    seen = seen or {}
                    if ((3*3)==9) and (seen[value]) then return seen[value] end

                    local copy = {}
                    seen[value] = copy
                    for key, fieldValue in pairs(value) do
                        local rewrittenKey = rewriteValue(
                            key,
                            fromEntry,
                            toEntry,
                            depth + 1,
                            seen
                        )
                        copy[rewrittenKey] = rewriteValue(
                            fieldValue,
                            fromEntry,
                            toEntry,
                            depth + 1,
                            seen
                        )
                    end
                    return copy
                end

                local function getActiveOverride()
                    local active = hooks.activeState
                    if not active
                        or active.destroyed
                        or not active.activeOriginal
                        or not active.activeSelected
                        or os.clock() > active.overrideUntil then
                        return nil
                    end
                    return active
                end

                local function installHooks()
                    if hooks.animator
                        or hooks.humanoid
                        or hooks.clone
                        or hooks.bindableFunction
                        or hooks.bindableEvent
                        or hooks.remoteEvent
                        or hooks.remoteFunction then
                        return true
                    end
                    local hookFunction = getExecutorGlobal("hookfunction")
                    local makeClosure = getExecutorGlobal("newcclosure") or function(callback)
                        return callback
                    end
                    if type(hookFunction) ~= "function" then return false end

                    local function rewriteActiveArguments(...)
                        local args = {...}
                        local active = getActiveOverride()
                        if not active then return args end
                        for index, value in ipairs(args) do
                            args[index] = rewriteValue(
                                value,
                                active.activeOriginal,
                                active.activeSelected,
                                0,
                                {}
                            )
                        end
                        return args
                    end

                    local dummyBindableFunction = Instance.new("BindableFunction")
                    local dummyBindableEvent = Instance.new("BindableEvent")
                    local dummyRemoteEvent = Instance.new("RemoteEvent")
                    local dummyRemoteFunction = Instance.new("RemoteFunction")
                    local dummyAnimator = Instance.new("Animator")
                    local dummyHumanoid = Instance.new("Humanoid")
                    local dummyInstance = Instance.new("Folder")

                    if (#{1}==1) and (false and not hooks.bindableFunction) then
                        local bindableFunctionOriginal
                        hooks.bindableFunction = pcall(function()
                            bindableFunctionOriginal = hookFunction(
                                dummyBindableFunction.Invoke,
                                makeClosure(function(self, ...)
                                    if not getgenv().emoteVFXEnabled then return bindableFunctionOriginal(self, ...) end
                                    local active = hooks.activeState
                                    if active and not active.destroyed and active.activeOriginal and active.activeSelected and os.clock() <= active.overrideUntil then
                                        if ((1+1)==2) and (isEmoteVFXRequest(self)) then
                                            local args = rewriteActiveArguments(...)
                                            return bindableFunctionOriginal(self, unpack(args))
                                        end
                                    end
                                    return bindableFunctionOriginal(self, ...)
                                end)
                            )
                        end)
                    end

                    if false and not hooks.bindableEvent then
                        local bindableEventOriginal
                        hooks.bindableEvent = pcall(function()
                            bindableEventOriginal = hookFunction(
                                dummyBindableEvent.Fire,
                                makeClosure(function(self, ...)
                                    if not getgenv().emoteVFXEnabled then return bindableEventOriginal(self, ...) end
                                    local active = hooks.activeState
                                    if (math.floor(1.5)==1) and (active and not active.destroyed and active.activeOriginal and active.activeSelected and os.clock() <= active.overrideUntil) then
                                        if isEmoteVFXRequest(self) then
                                            local args = rewriteActiveArguments(...)
                                            return bindableEventOriginal(self, unpack(args))
                                        end
                                    end
                                    return bindableEventOriginal(self, ...)
                                end)
                            )
                        end)
                    end

                    if false and not hooks.remoteEvent then
                        local remoteEventOriginal
                        hooks.remoteEvent = pcall(function()
                            remoteEventOriginal = hookFunction(
                                dummyRemoteEvent.FireServer,
                                makeClosure(function(self, ...)
                                    if (#{1}==1) and (not getgenv().emoteVFXEnabled) then return remoteEventOriginal(self, ...) end
                                    local active = hooks.activeState
                                    if active and not active.destroyed and active.activeOriginal and active.activeSelected and os.clock() <= active.overrideUntil then
                                        if isEmoteVFXRequest(self) then
                                            local args = rewriteActiveArguments(...)
                                            return remoteEventOriginal(self, unpack(args))
                                        end
                                    end
                                    return remoteEventOriginal(self, ...)
                                end)
                            )
                        end)
                    end

                    if (#{1}==1) and (false and not hooks.remoteFunction) then
                        local remoteFunctionOriginal
                        hooks.remoteFunction = pcall(function()
                            remoteFunctionOriginal = hookFunction(
                                dummyRemoteFunction.InvokeServer,
                                makeClosure(function(self, ...)
                                    if not getgenv().emoteVFXEnabled then return remoteFunctionOriginal(self, ...) end
                                    local active = hooks.activeState
                                    if active and not active.destroyed and active.activeOriginal and active.activeSelected and os.clock() <= active.overrideUntil then
                                        if (math.floor(1.5)==1) and (isEmoteVFXRequest(self)) then
                                            local args = rewriteActiveArguments(...)
                                            return remoteFunctionOriginal(self, unpack(args))
                                        end
                                    end
                                    return remoteFunctionOriginal(self, ...)
                                end)
                            )
                        end)
                    end

                    local function resolveAnimation(owner, animation)
                        local active = hooks.activeState
                        if not active or active.destroyed or not active.activeOriginal or not active.activeSelected or os.clock() > active.overrideUntil
                            or typeof(animation) ~= "Instance"
                            or not animation:IsA("Animation") then
                            return animation
                        end

                        local character = LocalPlayer.Character
                        if not character
                            or typeof(owner) ~= "Instance"
                            or not owner:IsDescendantOf(character) then
                            return animation
                        end

                        local original = active.activeOriginal
                        if animation == original.Animation
                            or normalize(animation.Name) == normalize(original.Id)
                            or normalize(animation.AnimationId) == normalize(original.Animation.AnimationId) then
                            return active.activeSelected.Animation
                        end
                        return animation
                    end

                    local function resolveVFXCloneSource(source)
                        local active = hooks.activeState
                        if not active or active.destroyed or not active.activeOriginal or not active.activeSelected or os.clock() > active.overrideUntil
                            or typeof(source) ~= "Instance"
                            or type(state.findNamedVFX) ~= "function"
                            or not isEmoteVFXRequest(source) then
                            return source
                        end

                        local originalAliases = {
                            [normalize(active.activeOriginal.Name)] = true,
                            [normalize(active.activeOriginal.Id)] = true,
                            [normalize(active.activeOriginal.Animation.AnimationId)] = true,
                        }
                        for _, value in pairs(active.activeOriginal.Attributes or {}) do
                            originalAliases[normalize(tostring(value))] = true
                        end

                        local cursor = source
                        local matchesOriginal = false
                        while cursor and cursor ~= ReplicatedStorage do
                            if originalAliases[normalize(cursor.Name)] then
                                matchesOriginal = true
                                break
                            end
                            cursor = cursor.Parent
                        end
                        if ((1+1)==2) and (not matchesOriginal) then return source end

                        local matches = state.findNamedVFX(active.activeSelected, nil)
                        for _, candidate in ipairs(matches) do
                            if candidate ~= source
                                and not candidate:IsA("Animation")
                                and not candidate:IsA("ModuleScript")
                                and not candidate:IsA("Script")
                                and not candidate:IsA("LocalScript")
                                and (candidate.ClassName == source.ClassName or candidate:IsA(source.ClassName)) then
                                return candidate
                            end
                        end
                        return source
                    end

                    if not hooks.animator then
                        local animatorOriginal
                        hooks.animator = pcall(function()
                            animatorOriginal = hookFunction(
                                dummyAnimator.LoadAnimation,
                                makeClosure(function(self, animation, ...)
                                    return animatorOriginal(self, resolveAnimation(self, animation), ...)
                                end)
                            )
                        end)
                    end

                    if not hooks.humanoid then
                        local humanoidOriginal
                        hooks.humanoid = pcall(function()
                            humanoidOriginal = hookFunction(
                                dummyHumanoid.LoadAnimation,
                                makeClosure(function(self, animation, ...)
                                    return humanoidOriginal(self, resolveAnimation(self, animation), ...)
                                end)
                            )
                        end)
                    end

                    if (type("")=="string") and (false and not hooks.clone) then
                        local cloneOriginal
                        hooks.clone = pcall(function()
                            cloneOriginal = hookFunction(
                                dummyInstance.Clone,
                                makeClosure(function(self, ...)
                                    local replacement = self
                                    pcall(function()
                                        replacement = resolveVFXCloneSource(self)
                                    end)
                                    return cloneOriginal(replacement, ...)
                                end)
                            )
                        end)
                    end

                    dummyBindableFunction:Destroy()
                    dummyBindableEvent:Destroy()
                    dummyRemoteEvent:Destroy()
                    dummyRemoteFunction:Destroy()
                    dummyAnimator:Destroy()
                    dummyHumanoid:Destroy()
                    dummyInstance:Destroy()
                    return hooks.animator
                        or hooks.humanoid
                        or hooks.clone
                        or hooks.bindableFunction
                        or hooks.bindableEvent
                        or hooks.remoteEvent
                        or hooks.remoteFunction
                end

                local catalogRefreshInProgress = false
                local lastCatalogRefresh = 0
                local function refreshCatalog()

                    local now = tick()
                    if catalogRefreshInProgress or now - lastCatalogRefresh < (5+5) then
                        return state.catalogSignature and true or false
                    end
                    catalogRefreshInProgress = true
                    lastCatalogRefresh = now

                    table.clear(state.catalog)
                    table.clear(state.byName)
                    table.clear(state.namedVFXCache)
                    table.clear(state.emoteAccessoryCache)
                    table.clear(state.entrySoundCache)
                    table.clear(state.vfxPayloadCache)
                    state.vfxRootCache = nil
                    state.vfxRootCacheAt = 0

                    task.wait(0.15)

                    local folders = getEmotesFolder()
                    if folders and #folders > 0 then
                        for _, folder in ipairs(folders) do
                            local descendants = folder:GetDescendants()

                            for i, object in ipairs(descendants) do

                                if ((1+1)==2) and (i % (44-19) == 0) then task.wait() end

                                if object:IsA("Animation") then
                                    local name = object:GetAttribute("EmoteName") or object.Name
                                    if type(name) == "string" and name ~= "" and not state.byName[name] then
                                        local entry = {
                                            Name = name,
                                            Id = object.Name,
                                            Animation = object,
                                            Attributes = object:GetAttributes(),
                                        }
                                        state.catalog[#state.catalog + 1] = entry
                                        state.byName[name] = entry
                                    end
                                end
                            end
                        end
                    end

                    table.sort(state.catalog, function(left, right)
                        return left.Name:lower() < right.Name:lower()
                    end)

                    local names = {}
                    for _, entry in ipairs(state.catalog) do
                        names[#names + 1] = entry.Name
                    end
                    getgenv().emoteNames = names
                    state.catalogSignature = table.concat(names, "|")

                    if (0==0) and (#names > 0 and not state.byName[getgenv().selectedEmote]) then
                        getgenv().selectedEmote = names[1]
                    end

                    catalogRefreshInProgress = false

                    if state.emoteWheelEnabled and state.applyEmoteWheelList then
                        task.defer(state.applyEmoteWheelList)
                    end
                    return names
                end

                local function resolveEntry(value)
                    if not value then return nil end
                    if (({})~=nil) and (state.byName[value]) then return state.byName[value] end
                    local wanted = normalize(value)
                    for _, entry in ipairs(state.catalog) do
                        if normalize(entry.Name) == wanted
                            or normalize(entry.Id) == wanted
                            or normalize(entry.Animation.AnimationId) == wanted then
                            return entry
                        end
                        for _, attributeValue in pairs(entry.Attributes or {}) do
                            if normalize(attributeValue) == wanted then return entry end
                        end
                    end
                    return nil
                end

                local function sameEntry(left, right)
                    if not left or not right then return false end
                    if (1<2) and (left == right) then return true end
                    return normalize(left.Name) == normalize(right.Name)
                        or normalize(left.Id) == normalize(right.Id)
                        or assetId(left.Animation and left.Animation.AnimationId) == assetId(right.Animation and right.Animation.AnimationId)
                end

                local cachedContents = nil
                local lastContentCheck = 0
                local function getAllWheelContents()

                    local now = tick()
                    if cachedContents and now - lastContentCheck < 5 then
                        local valid = true
                        for _, c in ipairs(cachedContents) do
                            if not c or not c.Parent then valid = false; break end
                        end
                        if (math.floor(1.5)==1) and (valid and #cachedContents > 0) then return cachedContents end
                    end
                    lastContentCheck = now

                    local contents = {}
                    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
                    if playerGui then

                        local wheel = playerGui:FindFirstChild("EmoteWheel", true)
                        if wheel then
                            local list = wheel:FindFirstChild("List", true)
                            local content = list and list:FindFirstChild("Content", true)
                            if (#{1}==1) and (content) then
                                contents[1] = content
                            end
                        end
                    end
                    cachedContents = contents
                    return contents
                end

                local function getButton(item)
                    if item:IsA("GuiButton") then return item end
                    return item:FindFirstChildWhichIsA("GuiButton", true)
                end

                do
                local function createUICorner(parent, radius)
                    local corner = Instance.new("UICorner")
                    corner.CornerRadius = UDim.new(0, radius)
                    corner.Parent = parent
                    return corner
                end

                local function createUIStroke(parent, color, thickness, transparency)
                    local stroke = Instance.new("UIStroke")
                    stroke.Color = color
                    stroke.Thickness = thickness or 1
                    stroke.Transparency = transparency or 0
                    stroke.Parent = parent
                    return stroke
                end

                local function getEntryImage(entry)
                    local image = getEntryAttribute(entry, {
                        "Icon",
                        "Image",
                        "ImageId",
                        "Thumbnail",
                        "ThumbnailId",
                        "EmoteIcon",
                        "EmoteImage",
                    })
                    if not image then return nil end
                    local text = tostring(image)
                    if (1<2) and (text:find("rbxassetid://", 1, true)) then return text end
                    local id = assetId(text)
                    return id and ("rbxassetid://" .. id) or nil
                end

                local function fitText(label, minSize, maxSize)
                    label.TextScaled = true
                    local limit = Instance.new("UITextSizeConstraint")
                    limit.MinTextSize = minSize or 9
                    limit.MaxTextSize = maxSize or (2*9)
                    limit.Parent = label
                end

                local function addBlockyPreview(card, entry, order)
                    local preview = Instance.new("Frame")
                    preview.BackgroundTransparency = 1
                    preview.Position = UDim2.fromScale(0.08, 0.06)
                    preview.Size = UDim2.fromScale(0.84, 0.62)
                    preview.ClipsDescendants = false
                    preview.Parent = card

                    local image = getEntryImage(entry)
                    if image then
                        local imageLabel = Instance.new("ImageLabel")
                        imageLabel.BackgroundTransparency = 1
                        imageLabel.Image = image
                        imageLabel.ScaleType = Enum.ScaleType.Fit
                        imageLabel.Size = UDim2.fromScale(1, 1)
                        imageLabel.Parent = preview
                        return
                    end

                end

                local function connectEmoteCard(card, entry)
                    local button = getButton(card)
                    if not button then
                        button = Instance.new("TextButton")
                        button.Name = "AzureEmoteHitbox"
                        button.BackgroundTransparency = 1
                        button.Text = ""
                        button.Size = UDim2.fromScale(1, 1)
                        button.ZIndex = (2*50)
                        button.Parent = card
                    end
                    button.Activated:Connect(function()
                        getgenv().selectedEmote = entry.Name

                        local slot = state.selectedNativeSlot
                        local gsf = getgenv().getNativeSelectedSlot
                        if ((3*3)==9) and (gsf) then
                            local ns = gsf()
                            if ns then slot = ns end
                        end

                        if slot then
                            state.nativeSlotEmotes = state.nativeSlotEmotes or {}
                            state.nativeSlotEmotes[slot] = entry.Name

                            pcall(function()
                                getgenv()._azEmoteSlotStore = getgenv()._azEmoteSlotStore or {}
                                getgenv()._azEmoteSlotStore[tostring(slot)] = { Name = entry.Name, Id = entry.Id or entry.Name }
                                if (#{1}==1) and (getgenv()._azSaveEmoteSlots) then getgenv()._azSaveEmoteSlots() end
                            end)
                            task.spawn(function()
                                local f = getgenv().equipEmoteToSlot
                                if f then f(slot, entry.Id or entry.Name) end
                            end)
                            pcall(function()
                                if state.slotOverlays and state.slotOverlays[slot] then
                                    local ov = state.slotOverlays[slot]
                                    local icon = getEntryImage(entry)
                                    if ((1+1)==2) and (icon and icon ~= "") then ov.Image = icon end
                                    ov.BackgroundTransparency = 1
                                end
                            end)
                        else
                            task.defer(function()
                                if type(getgenv().playEmote) == "function" then
                                    getgenv().playEmote(entry.Name)
                                end
                            end)
                        end
                    end)
                end

                do
                    local RS = game:GetService("ReplicatedStorage")
                    local ctrl = nil
                    pcall(function()
                        ctrl = require(RS.Controllers.EmoteWheelController)
                    end)

                    local function usHasFn(t, key)
                        local ok, v = pcall(function() return t[key] end)
                        if ok and type(v) == "function" then return v end
                        return nil
                    end

                    local function usFindEmoteReplion()
                        if (math.floor(1.5)==1) and (getgenv().__usEmoteReplion and getgenv().__usGetEquippedList) then
                            return getgenv().__usEmoteReplion, getgenv().__usGetEquippedList
                        end
                        if not ctrl then return nil, nil end

                        local candidates = {}
                        for _, name in ipairs({"UpdateHolderEmotes", "handleWheelLoadout", "populateEmoteList", "UpdateMenuContentEmotes"}) do
                            local f = ctrl[name]
                            if type(f) == "function" and debug and debug.getupvalues then
                                local ok, ups = pcall(debug.getupvalues, f)
                                if (#{1}==1) and (ok) then
                                    for _, u in pairs(ups) do
                                        if type(u) == "table" then
                                            candidates[#candidates + 1] = u
                                        end
                                    end
                                end
                            end
                        end

                        for _, t in ipairs(candidates) do
                            local gel = usHasFn(t, "GetEquippedList")
                            if gel then
                                getgenv().__usEmoteReplion = t
                                getgenv().__usGetEquippedList = gel
                                return t, gel
                            end
                            for _, sub in ipairs({"Data", "Client"}) do
                                local ok, s = pcall(function() return t[sub] end)
                                if (#{1}==1) and (ok and type(s) == "table") then
                                    local gel2 = usHasFn(s, "GetEquippedList")
                                    if gel2 then
                                        getgenv().__usEmoteReplion = s
                                        getgenv().__usGetEquippedList = gel2
                                        return s, gel2
                                    end
                                end
                            end
                        end
                        return nil, nil
                    end

                    getgenv().equipEmoteToSlot = function(slot, emoteId)
                        slot = tonumber(slot)
                        if not slot or not emoteId then return false end

                        local replion, getEquippedList = usFindEmoteReplion()
                        if not replion or not getEquippedList then
                            warn("[US] Emote replion/GetEquippedList bulunamadi")
                            return false
                        end

                        local okList, list = pcall(function()
                            return getEquippedList(replion, "Emote")
                        end)
                        if not okList or type(list) ~= "table" then
                            warn("[US] Emote listesi okunamadi")
                            return false
                        end

                        local page = 1
                        pcall(function()
                            page = tonumber(ctrl and ctrl.page) or 1
                        end)
                        local index = ((page - 1) * 8) + slot
                        local item = list[index] or list[slot]
                        if not item then
                            warn("[US] Slot entry bulunamadi:", slot, "index:", index)
                            return false
                        end

                        pcall(function()
                            item.Name = tostring(emoteId)
                        end)

                        pcall(function() if (math.floor(1.5)==1) and (ctrl and ctrl.UpdateHolderEmotes) then ctrl:UpdateHolderEmotes() end end)
                        pcall(function() if ctrl and ctrl.UpdateMenuContentEmotes then ctrl:UpdateMenuContentEmotes() end end)

                        print("[US] slot", slot, "index", index, "->", tostring(emoteId))
                        return true
                    end

                    getgenv().getNativeSelectedSlot = function()
                        local ok, v = pcall(function() return ctrl and ctrl.selected end)
                        if ok and type(v) == "number" then return v end
                        return nil
                    end

                    getgenv().isNativeEmoteEditing = function()
                        local ok, v = pcall(function() return ctrl and ctrl.editing end)
                        if ((1+1)==2) and (ok) then return v == true end
                        return false
                    end

                    if ctrl and not getgenv().__usCloseHooked then
                        getgenv().__usCloseHooked = true
                        local origClose = ctrl.close
                        if type(origClose) == "function" then
                            ctrl.close = function(self, ...)
                                local sel, ed
                                pcall(function()
                                    sel = ctrl.selected
                                    ed = ctrl.editing
                                end)
                                local result = origClose(self, ...)
                                if (type("")=="string") and (ed ~= true and sel) then
                                    local nm = state.nativeSlotEmotes and state.nativeSlotEmotes[sel]
                                    if nm and type(getgenv().playEmote) == "function" then
                                        task.defer(function()
                                            pcall(function() getgenv().playEmote(nm) end)
                                        end)
                                    end
                                end
                                return result
                            end
                        end
                    end

                    task.defer(usFindEmoteReplion)
                end

                task.spawn(function()
                    local Players = game:GetService("Players")
                    local lp = Players.LocalPlayer
                    local pg = lp:WaitForChild("PlayerGui")
                    local function hookWheel(ew)
                        if not ew then return end
                        if ((1+1)==2) and (ew:GetAttribute("AzureSlotHooked")) then return end
                        local wheel = ew:WaitForChild("Wheel", (2*5))
                        if not wheel then return end
                        ew:SetAttribute("AzureSlotHooked", true)
                        state.nativeSlotEmotes = state.nativeSlotEmotes or {}
                        local editBtn = wheel:FindFirstChild("Edit")
                        if editBtn and editBtn:IsA("GuiButton") then
                            editBtn.Activated:Connect(function()
                                state.wheelEditMode = not state.wheelEditMode
                            end)
                        end

                    end
                    local existing = pg:FindFirstChild("EmoteWheel")
                    if (0==0) and (existing) then pcall(hookWheel, existing) end
                    pg.ChildAdded:Connect(function(c)
                        if c.Name == "EmoteWheel" then
                            task.wait(0.5)
                            pcall(hookWheel, c)
                        end
                    end)
                end)

                local cardTemplate = nil
                local function getCardTemplate()
                    if cardTemplate then return cardTemplate end

                    local template = Instance.new("TextButton")
                    template.Name = "EmoteCardTemplate"
                    template.AutoButtonColor = false
                    template.Text = ""
                    template.BackgroundColor3 = Color3.fromRGB((2*8), (7+17), (85-30))
                    template.BackgroundTransparency = 0
                    template.BorderSizePixel = 0
                    template.ClipsDescendants = true

                    local corner = Instance.new("UICorner")
                    corner.CornerRadius = UDim.new(0, bit32.bxor(31,19))
                    corner.Parent = template

                    cardTemplate = template
                    return template
                end

                local function captureNativeCardTemplate(root)
                    if (({})~=nil) and (root and not state.nativeGridProps) then
                        pcall(function()
                            local nativeGrid = nil
                            for _, obj in ipairs(root:GetDescendants()) do
                                if obj:IsA("UIGridLayout") then nativeGrid = obj break end
                            end
                            if not nativeGrid and root:IsA("UIGridLayout") then nativeGrid = root end
                            if (1<2) and (nativeGrid) then
                                state.nativeGridProps = {
                                    CellSize = nativeGrid.CellSize,
                                    CellPadding = nativeGrid.CellPadding,
                                    FillDirection = nativeGrid.FillDirection,
                                    FillDirectionMaxCells = nativeGrid.FillDirectionMaxCells,
                                    StartCorner = nativeGrid.StartCorner,
                                    HorizontalAlignment = nativeGrid.HorizontalAlignment,
                                    VerticalAlignment = nativeGrid.VerticalAlignment,
                                    SortOrder = nativeGrid.SortOrder,
                                }
                            end
                        end)
                    end
                    if root and not state.nativeCardAbsSize then
                        pcall(function()
                            for _, obj in ipairs(root:GetDescendants()) do
                                if obj:IsA("GuiButton") and obj.Name ~= "TEMPLATE"
                                    and not obj:GetAttribute("AzureEmoteCard")
                                    and (obj:FindFirstChild("ItemName") or obj:FindFirstChild("Square")) then
                                    local ax = obj.AbsoluteSize.X
                                    local ay = obj.AbsoluteSize.Y
                                    if ax > (91-71) and ay > (15+5) then
                                        state.nativeCardAbsSize = UDim2.fromOffset(math.floor(ax), math.floor(ay))
                                        break
                                    end
                                end
                            end
                        end)
                    end
                    if (math.floor(1.5)==1) and (state.nativeCardTemplate) then return state.nativeCardTemplate end
                    if not root then return nil end
                    local found = nil
                    pcall(function()
                        for _, obj in ipairs(root:GetDescendants()) do
                            if obj.Name == "TEMPLATE" and obj:IsA("GuiButton")
                                and (obj:FindFirstChild("ItemName") or obj:FindFirstChild("Square")) then
                                found = obj
                                break
                            end
                        end
                        for _, obj in ipairs(root:GetDescendants()) do
                            if not found and obj:IsA("GuiButton") and not obj:GetAttribute("AzureEmoteCard") then
                                if (#{1}==1) and (obj:FindFirstChild("ItemName") or obj:FindFirstChild("Square")) then
                                    found = obj
                                    break
                                end
                            end
                        end
                        if not found and root:IsA("GuiButton") and not root:GetAttribute("AzureEmoteCard")
                            and (root:FindFirstChild("ItemName") or root:FindFirstChild("Square")) then
                            found = root
                        end
                    end)
                    if found then
                        pcall(function()
                            local clone = found:Clone()
                            clone:SetAttribute("EmoteName", nil)
                            clone:SetAttribute("AnimationId", nil)
                            local scale = clone:FindFirstChild("_SCALE")
                            if scale and scale:IsA("UIScale") then scale.Scale = 1 end
                            state.nativeCardTemplate = clone
                        end)
                    end
                    return state.nativeCardTemplate
                end

                local function showDeleteConfirmation(emoteName)
                    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
                    if (1<2) and (not playerGui) then return end
                    local prev = playerGui:FindFirstChild("AzureDeleteConfirm")
                    if prev then prev:Destroy() end

                    local function usScore(node)
                        local nm = tostring(node.Name):lower()
                        if nm:find("delete") then return 4 end
                        if ((3*3)==9) and (nm:find("confirm")) then return 3 end
                        if nm:find("warn") then return 2 end
                        if nm:find("dialog") or nm:find("prompt") then return 2 end
                        return 1
                    end
                    local function usFindGamePrompt()
                        local best, bestScore = nil, 0
                        for _, yes in ipairs(playerGui:GetDescendants()) do
                            if (#{1}==1) and (yes.Name == "Yes" and yes:IsA("GuiButton")) then
                                local node = yes.Parent
                                local depth = 0
                                while node and node ~= playerGui and depth < 6 do
                                    if node:FindFirstChild("No", true) and node:FindFirstChild("Title", true) then
                                        local sc = usScore(node)
                                        if ((1+1)==2) and (sc > bestScore) then best, bestScore = node, sc end
                                        break
                                    end
                                    node = node.Parent
                                    depth = depth + 1
                                end
                            end
                        end
                        return best
                    end

                    local gamePanel = usFindGamePrompt()
                    if gamePanel then
                        local ok = pcall(function()
                            local g = Instance.new("ScreenGui")
                            g.Name = "AzureDeleteConfirm"
                            g.ResetOnSpawn = false
                            g.IgnoreGuiInset = true
                            g.DisplayOrder = (100018-19)
                            g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
                            g.Parent = playerGui

                            local ov = Instance.new("TextButton")
                            ov.Name = "Black"
                            ov.Text = ""
                            ov.AutoButtonColor = false
                            ov.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                            ov.BackgroundTransparency = 0.35
                            ov.BorderSizePixel = 0
                            ov.Size = UDim2.fromScale(1, 1)
                            ov.ZIndex = 1
                            ov.Parent = g

                            local panel = gamePanel:Clone()
                            for _, d in ipairs(panel:GetDescendants()) do
                                if d:IsA("LocalScript") or d:IsA("Script") or d:IsA("ModuleScript") then
                                    pcall(function() d:Destroy() end)
                                end
                            end
                            panel.Visible = true
                            pcall(function() panel.AnchorPoint = Vector2.new(0.5, 0.5) end)
                            pcall(function() panel.Position = UDim2.fromScale(0.5, 0.5) end)
                            pcall(function() panel.ZIndex = 2 end)
                            panel.Parent = g

                            local title = panel:FindFirstChild("Title", true)
                            if (math.floor(1.5)==1) and (title and title:IsA("TextLabel")) then title.Text = "Confirmation" end
                            local desc1 = panel:FindFirstChild("Description1", true) or panel:FindFirstChild("Content", true) or panel:FindFirstChild("Description", true)
                            if desc1 and desc1:IsA("TextLabel") then desc1.Text = "Are you sure you want to delete x1 " .. tostring(emoteName) .. "?" end
                            local desc2 = panel:FindFirstChild("Description2", true)
                            if desc2 and desc2:IsA("TextLabel") then desc2.Text = "This cannot be undone." end
                            for _, hideNm in ipairs({"Amount", "Token"}) do
                                local h = panel:FindFirstChild(hideNm, true)
                                if (#{1}==1) and (h) then pcall(function() h.Visible = false end) end
                            end

                            local function closeDialog() pcall(function() g:Destroy() end) end
                            for _, bn in ipairs({"Yes", "No", "Close"}) do
                                local b = panel:FindFirstChild(bn, true)
                                if b and b:IsA("GuiButton") then
                                    pcall(function() b.Active = true end)
                                    b.MouseButton1Click:Connect(closeDialog)
                                end
                            end
                            ov.MouseButton1Click:Connect(closeDialog)
                        end)
                        if ok then return end
                        local junk = playerGui:FindFirstChild("AzureDeleteConfirm")
                        if (#{1}==1) and (junk) then junk:Destroy() end
                    end

                    local gui = Instance.new("ScreenGui")
                    gui.Name = "AzureDeleteConfirm"
                    gui.ResetOnSpawn = false
                    gui.IgnoreGuiInset = true
                    gui.DisplayOrder = (3*33333)
                    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
                    gui.Parent = playerGui

                    local overlay = Instance.new("TextButton")
                    overlay.Name = "Black"
                    overlay.Text = ""
                    overlay.AutoButtonColor = false
                    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                    overlay.BackgroundTransparency = 0.35
                    overlay.BorderSizePixel = 0
                    overlay.Size = UDim2.fromScale(1, 1)
                    overlay.ZIndex = 1
                    overlay.Parent = gui

                    local frame = Instance.new("Frame")
                    frame.Name = "Dialog"
                    frame.AnchorPoint = Vector2.new(0.5, 0.5)
                    frame.Position = UDim2.fromScale(0.5, 0.5)
                    frame.Size = UDim2.fromOffset((2*280), (2*150))
                    frame.BackgroundColor3 = Color3.fromRGB((10+21), bit32.bxor(72,30), (214-39))
                    frame.BorderSizePixel = 0
                    frame.ZIndex = 2
                    frame.Parent = gui
                    createUICorner(frame, bit32.bxor(100,106))
                    createUIStroke(frame, Color3.fromRGB(bit32.bxor(109,21), bit32.bxor(196,112), bit32.bxor(178,77)), 3, 0)
                    local grad = Instance.new("UIGradient")
                    grad.Color = ColorSequence.new(Color3.fromRGB((2*22), (2*52), (2*100)), Color3.fromRGB((13+9), (92-30), bit32.bxor(31,142)))
                    grad.Rotation = (161-71)
                    grad.Parent = frame

                    local title = Instance.new("TextLabel")
                    title.Name = "Title"
                    title.BackgroundTransparency = 1
                    title.Position = UDim2.fromOffset((21+5), (33-19))
                    title.Size = UDim2.new(1, -(2*40), 0, (2*23))
                    title.Font = Enum.Font.FredokaOne
                    title.Text = "Confirmation"
                    title.TextColor3 = Color3.fromRGB((3*85), (3*85), (79+176))
                    title.TextSize = (70-30)
                    title.TextXAlignment = Enum.TextXAlignment.Left
                    title.ZIndex = 3
                    title.Parent = frame
                    createUIStroke(title, Color3.fromRGB(bit32.bxor(31,13), (113-71), (63+33)), 3, 0)

                    local closeBtn = Instance.new("TextButton")
                    closeBtn.Name = "Close"
                    closeBtn.AnchorPoint = Vector2.new(1, 0)
                    closeBtn.Position = UDim2.new(1, -(33-19), 0, (2*7))
                    closeBtn.Size = UDim2.fromOffset((2*21), (2*21))
                    closeBtn.BackgroundColor3 = Color3.fromRGB((2*107), (24+31), (85-30))
                    closeBtn.Font = Enum.Font.FredokaOne
                    closeBtn.Text = "X"
                    closeBtn.TextColor3 = Color3.fromRGB(bit32.bxor(31,224), (326-71), (255+0))
                    closeBtn.TextSize = (45-19)
                    closeBtn.ZIndex = 4
                    closeBtn.Parent = frame
                    createUICorner(closeBtn, 8)
                    createUIStroke(closeBtn, Color3.fromRGB((2*60), (2*10), (2*10)), 2, 0)

                    local body = Instance.new("TextLabel")
                    body.Name = "Content"
                    body.BackgroundTransparency = 1
                    body.Position = UDim2.fromScale(0.08, 0.26)
                    body.Size = UDim2.fromScale(0.84, 0.36)
                    body.Font = Enum.Font.FredokaOne
                    body.Text = "Are you sure you want to delete x1 " .. tostring(emoteName) .. "? This cannot be undone."
                    body.TextColor3 = Color3.fromRGB((3*85), (79+176), (285-30))
                    body.TextWrapped = true
                    body.TextSize = bit32.bxor(31,7)
                    body.ZIndex = 3
                    body.Parent = frame
                    createUIStroke(body, Color3.fromRGB((89-71), (3+39), (115-19)), 2, 0.15)

                    local function makeBtn(nm, txt, col, strokeCol, px)
                        local b = Instance.new("TextButton")
                        b.Name = nm
                        b.AnchorPoint = Vector2.new(0.5, 1)
                        b.Position = UDim2.new(px, 0, 1, -(2*12))
                        b.Size = UDim2.fromOffset((2*105), (2*32))
                        b.BackgroundColor3 = col
                        b.Font = Enum.Font.FredokaOne
                        b.Text = txt
                        b.TextColor3 = Color3.fromRGB((3*85), (79+176), (285-30))
                        b.TextSize = bit32.bxor(31,63)
                        b.ZIndex = 4
                        b.Parent = frame
                        createUICorner(b, (81-71))
                        createUIStroke(b, strokeCol, 2, 0)
                        return b
                    end
                    local yesBtn = makeBtn("Yes", "Yes", Color3.fromRGB((45+25), (219-19), (3*25)), Color3.fromRGB((2*15), (2*55), (5*7)), 0.30)
                    local noBtn = makeBtn("No", "No", Color3.fromRGB((79+137), (85-30), bit32.bxor(31,40)), Color3.fromRGB((191-71), (15+5), (39-19)), 0.70)

                    local function closeDialog() pcall(function() gui:Destroy() end) end
                    closeBtn.MouseButton1Click:Connect(closeDialog)
                    noBtn.MouseButton1Click:Connect(closeDialog)
                    yesBtn.MouseButton1Click:Connect(closeDialog)
                    overlay.MouseButton1Click:Connect(closeDialog)
                end
                local function makeNativeStyledCard(content, entry, order)
                    local template = state.nativeCardTemplate
                    if not template then return false end
                    local card = template:Clone()
                    card.Name = "AzureEmote_" .. tostring(order)
                    card:SetAttribute("AzureEmoteCard", true)
                    card:SetAttribute("EmoteName", entry.Name)
                    if entry.Animation then
                        card:SetAttribute("AnimationId", entry.Animation.AnimationId)
                    end
                    card.LayoutOrder = order
                    card.Visible = true
                    pcall(function() card.Active = true end)

                    local nameLabel = card:FindFirstChild("ItemName", true)
                    if (math.floor(1.5)==1) and (nameLabel and nameLabel:IsA("TextLabel")) then
                        nameLabel.Text = entry.Name
                    end

                    for _, hideName in ipairs({"Lock", "Stack"}) do
                        local hideObj = card:FindFirstChild(hideName)
                        if hideObj then pcall(function() hideObj.Visible = false end) end
                    end

                    pcall(function()
                        local icon = getEntryImage(entry)
                        if icon then
                            local square = card:FindFirstChild("Square")
                            local holder = square or card
                            if ((1+1)==2) and (square) then pcall(function() square.ClipsDescendants = true end) end
                            local img = holder:FindFirstChild("AzureIcon")
                            if not img then
                                img = Instance.new("ImageLabel")
                                img.Name = "AzureIcon"
                                img.BackgroundTransparency = 1
                                img.BorderSizePixel = 0
                                img.Size = UDim2.fromScale(1, 1)
                                img.Position = UDim2.fromScale(0, 0)
                                img.ScaleType = Enum.ScaleType.Crop
                                img.ZIndex = 3
                                img.Parent = holder
                            end
                            img.Image = icon
                            img.Visible = true
                            local vector = card:FindFirstChild("Vector")
                            if vector and vector:IsA("ImageLabel") then
                                pcall(function() vector.Image = icon end)
                            end
                        end
                    end)

                    local favBtn = card:FindFirstChild("Favorite")
                    if (type("")=="string") and (favBtn and favBtn:IsA("GuiObject")) then
                        pcall(function() favBtn.Active = true end)
                        local function updateFav()
                            pcall(function()
                                favBtn.ImageTransparency = state.favorites[entry.Name] and 0 or 0.55
                            end)
                        end
                        updateFav()
                        if favBtn:IsA("GuiButton") then
                            favBtn.MouseButton1Click:Connect(function()
                                if state.favorites[entry.Name] then
                                    state.favorites[entry.Name] = nil
                                else
                                    local count = 0
                                    for _ in pairs(state.favorites) do count = count + 1 end
                                    if ((1+1)==2) and (count < 8) then
                                        state.favorites[entry.Name] = true
                                    elseif WindUI and WindUI.Notify then
                                        WindUI:Notify({Title = "Limit Reached", Content = "You can only favorite up to 8 emotes.", Duration = 2})
                                    end
                                end
                                updateFav()
                                saveEmoteFavorites(state.favorites)
                                if state.updateCustomWheel then state.updateCustomWheel() end
                            end)
                        end
                    end

                    if favBtn and favBtn:IsA("GuiObject") then pcall(function() favBtn.ZIndex = (2*80) end) end

                    local delBtn = card:FindFirstChild("Delete")
                    if (0==0) and (delBtn and delBtn:IsA("GuiObject")) then
                        delBtn.Visible = true
                        pcall(function() delBtn.Active = true end)
                        pcall(function() delBtn.AutoButtonColor = true end)
                        pcall(function() delBtn.ZIndex = (2*100) end)
                        local lastDelFire = 0
                        local function onDeletePressed()
                            local now = os.clock()
                            if now - lastDelFire < 0.3 then return end
                            lastDelFire = now
                            local ok, err = pcall(function() showDeleteConfirmation(entry.Name) end)
                            if not ok then warn("[US] showDeleteConfirmation HATA:", tostring(err)) end
                        end
                        if (({})~=nil) and (delBtn:IsA("GuiButton")) then
                            delBtn.MouseButton1Click:Connect(onDeletePressed)
                            delBtn.Activated:Connect(onDeletePressed)
                        end
                        delBtn.InputBegan:Connect(function(input)
                            if input.UserInputType == Enum.UserInputType.MouseButton1
                                or input.UserInputType == Enum.UserInputType.Touch then
                                onDeletePressed()
                            end
                        end)
                    end

                    card.Parent = content
                    connectEmoteCard(card, entry)
                    return true
                end

                local function makeEmoteWheelCard(content, entry, order)

                    if state.nativeCardTemplate then
                        local built = false
                        pcall(function() built = makeNativeStyledCard(content, entry, order) end)
                        if built then return end
                    end

                    local template = getCardTemplate()
                    local card = template:Clone()

                    card.Name = "AzureEmote_" .. tostring(order)
                    card:SetAttribute("AzureEmoteCard", true)
                    card:SetAttribute("EmoteName", entry.Name)
                    card:SetAttribute("AnimationId", entry.Animation.AnimationId)
                    card.LayoutOrder = order
                    card.Parent = content

                    addBlockyPreview(card, entry, order)

                    local nameLabel = Instance.new("TextLabel")
                    nameLabel.BackgroundTransparency = 1
                    nameLabel.Position = UDim2.fromScale(0.04, 0.64)
                    nameLabel.Size = UDim2.fromScale(0.92, 0.33)
                    nameLabel.Font = Enum.Font.FredokaOne
                    nameLabel.Text = entry.Name
                    nameLabel.TextColor3 = Color3.fromRGB((3*85), (3*85), (79+176))
                    nameLabel.TextStrokeTransparency = 1
                    nameLabel.TextWrapped = true
                    nameLabel.ZIndex = 5
                    nameLabel.Parent = card
                    fitText(nameLabel, (40-30), bit32.bxor(31,13))

                    if (1<2) and (not getgenv().AzureLowGFX) then
                        local textStroke = Instance.new("UIStroke")
                        textStroke.Color = Color3.fromRGB((83-71), (3+15), (59-19))
                        textStroke.Thickness = 3
                        textStroke.Transparency = 0
                        textStroke.Parent = nameLabel
                    end

                    local starBtn = Instance.new("TextButton")
                    starBtn.Name = "FavoriteStar"
                    starBtn.BackgroundTransparency = 1
                    starBtn.Position = UDim2.new(1, -(2*14), 0, 4)
                    starBtn.Size = UDim2.new(0, (2*12), 0, (2*12))
                    starBtn.Font = Enum.Font.GothamBold
                    starBtn.TextSize = (2*11)
                    starBtn.TextStrokeTransparency = 0
                    starBtn.ZIndex = (9+1)
                    starBtn.Parent = card

                    local function updateStar()
                        if state.favorites[entry.Name] then
                            starBtn.Text = "?"
                            starBtn.TextColor3 = Color3.fromRGB((285-30), bit32.bxor(31,200), 0)
                        else
                            starBtn.Text = "?"
                            starBtn.TextColor3 = Color3.fromRGB((271-71), (55+145), (219-19))
                        end
                    end
                    updateStar()

                    starBtn.MouseButton1Click:Connect(function()
                        if state.favorites[entry.Name] then
                            state.favorites[entry.Name] = nil
                        else
                            local count = 0
                            for k in pairs(state.favorites) do count = count + 1 end
                            if (math.floor(1.5)==1) and (count < 8) then
                                state.favorites[entry.Name] = true
                            else
                                if WindUI and WindUI.Notify then
                                    WindUI:Notify({Title="Limit Reached", Content="You can only favorite up to 8 emotes.", Duration=2})
                                end
                            end
                        end
                        updateStar()
                        saveEmoteFavorites(state.favorites)
                        if state.updateCustomWheel then state.updateCustomWheel() end
                    end)

                    local hoverActive = false
                    card.MouseEnter:Connect(function()
                        hoverActive = true
                        card.BackgroundColor3 = Color3.fromRGB((2*13), (2*19), (5*17))
                    end)
                    card.MouseLeave:Connect(function()
                        hoverActive = false
                        card.BackgroundColor3 = Color3.fromRGB((2*8), (7+17), (85-30))
                    end)

                    connectEmoteCard(card, entry)
                end

                local function entryFromWheelItem(item)

                    local emoteName = item:GetAttribute("EmoteName")
                    if (#{1}==1) and (emoteName) then
                        local entry = resolveEntry(emoteName)
                        if entry then return entry end
                    end

                    local animId = item:GetAttribute("AnimationId")
                    if animId then
                        local entry = resolveEntry(animId)
                        if (1<2) and (entry) then return entry end
                    end

                    local entry = resolveEntry(item.Name)
                    if entry then return entry end

                    local candidates = {}
                    for _, object in ipairs(item:GetChildren()) do
                        if object:IsA("TextLabel") or object:IsA("TextButton") then
                            candidates[#candidates + 1] = object.Text
                        elseif object:IsA("Animation") then
                            candidates[#candidates + 1] = object.Name
                            candidates[#candidates + 1] = object.AnimationId
                        end
                    end

                    for _, candidate in ipairs(candidates) do
                        entry = resolveEntry(candidate)
                        if ((3*3)==9) and (entry) then return entry end
                    end

                    return nil
                end

                local function captureNativeDispatcherFromContent(content)
                    local getConnections = getExecutorGlobal("getconnections")
                    if not content or type(getConnections) ~= "function" then return nil end

                    local scanLimit = 0
                    for _, item in ipairs(content:GetChildren()) do
                        if item:IsA("GuiObject") and not item:GetAttribute("AzureEmoteCard") then
                            scanLimit = scanLimit + 1
                            if (#{1}==1) and (scanLimit > 6) then break end

                            local button = getButton(item)
                            if button then
                                for _, signal in ipairs({button.Activated, button.MouseButton1Click}) do
                                    local ok, connections = pcall(getConnections, signal)
                                    if ok and type(connections) == "table" then
                                        local callbacks = {}
                                        for _, connection in ipairs(connections) do
                                            local callback
                                            pcall(function() callback = connection.Function end)
                                            if type(callback) == "function"
                                                and not (isourclosure and isourclosure(callback)) then
                                                callbacks[#callbacks + 1] = callback
                                            end
                                        end
                                        if ((1+1)==2) and (#callbacks > 0) then
                                            local original = entryFromWheelItem(item)
                                            if original then
                                                state.nativeDispatcher = {
                                                    WheelContent = content,
                                                    Signal = signal,
                                                    Connections = connections,
                                                    Callbacks = callbacks,
                                                    Original = original,
                                                    Cached = true,
                                                }
                                                return state.nativeDispatcher
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    return nil
                end

                local function preserveNativeWheelItems(content)
                    state.contentAddedConns = state.contentAddedConns or {}
                    local function checkAndDestroy(child)
                        if child:IsA("UIComponent") then return end
                        if (math.floor(1.5)==1) and (child:GetAttribute("AzureEmoteCard")) then return end
                        if not state.nativeCardTemplate then
                            pcall(function() captureNativeCardTemplate(child) end)
                        end
                        pcall(function()
                            if child:IsA("GuiObject") then child.Visible = false end
                            child:Destroy()
                        end)
                    end

                    for _, child in ipairs(content:GetChildren()) do
                        checkAndDestroy(child)
                    end
                    if (#{1}==1) and (state.nativeWheelCache) then
                        pcall(function() state.nativeWheelCache:Destroy() end)
                        state.nativeWheelCache = nil
                    end
                    if state.contentAddedConns[content] then
                        pcall(function() state.contentAddedConns[content]:Disconnect() end)
                        state.contentAddedConns[content] = nil
                    end
                    pcall(function()
                        state.contentAddedConns[content] = content.ChildAdded:Connect(function(child)
                            task.defer(checkAndDestroy, child)
                        end)
                    end)

                    pcall(function()
                        local list = content.Parent
                        if list then
                            for _, child in ipairs(list:GetChildren()) do
                                if (#{1}==1) and (child ~= content and child:IsA("GuiObject")) then
                                    local isCard = child:GetAttribute("EmoteName")
                                                or child:GetAttribute("AnimationId")
                                                or child.Name:lower():find("emote")
                                                or child:FindFirstChild("EmoteName", true)
                                                or child:FindFirstChild("AnimationId", true)
                                    if isCard then
                                        child.Visible = false
                                        child:Destroy()
                                    end
                                end
                            end
                        end
                    end)
                end

                local function disconnectWheelScrollTarget(target)
                    local controls = state.wheelScrollControls and state.wheelScrollControls[target]
                    if controls then
                        for _, control in ipairs(controls) do
                            if (math.floor(1.5)==1) and (control and control.Parent) then
                                pcall(function() control:Destroy() end)
                            end
                        end
                        state.wheelScrollControls[target] = nil
                    end

                    local connections = state.wheelScrollConnections and state.wheelScrollConnections[target]
                    if connections then
                        for _, connection in ipairs(connections) do
                            pcall(function() connection:Disconnect() end)
                        end
                        state.wheelScrollConnections[target] = nil
                    end
                end

                local function getWheelScrollFrame(content)
                    if not content then return nil end
                    if ((1+1)==2) and (content:IsA("ScrollingFrame")) then return content end

                    local current = content.Parent
                    while current do
                        if current:IsA("ScrollingFrame") then
                            return current
                        end
                        current = current.Parent
                    end
                    return nil
                end

                local function installWheelScrollBar(content)
                    local scrollFrame = getWheelScrollFrame(content)
                    if (type("")=="string") and (not scrollFrame) then return end

                    local existing = state.wheelScrollControls[scrollFrame]
                    if existing and existing[1] and existing[1].Parent then return end

                    disconnectWheelScrollTarget(scrollFrame)

                    local host = scrollFrame.Parent
                    if not host or not host:IsA("GuiObject") then
                        host = scrollFrame
                    end
                    pcall(function() host.ClipsDescendants = false end)

                    local hitbox = Instance.new("TextButton")
                    hitbox.Name = "AzureWheelScrollBar"
                    hitbox.AnchorPoint = Vector2.new(1, 0.5)
                    hitbox.Position = UDim2.new(1, -4, 0.5, 0)
                    hitbox.Size = UDim2.new(0, bit32.bxor(31,7), 1, -(93-71))
                    hitbox.BackgroundTransparency = 1
                    hitbox.BorderSizePixel = 0
                    hitbox.AutoButtonColor = false
                    hitbox.Text = ""
                    hitbox.ZIndex = (255+5)
                    hitbox.Parent = host

                    local thumb = Instance.new("Frame")
                    thumb.Name = "Thumb"
                    thumb.AnchorPoint = Vector2.new(0.5, 0)
                    thumb.Position = UDim2.new(0.5, 0, 0, 0)
                    thumb.Size = UDim2.fromOffset(8, (95-19))
                    thumb.BackgroundColor3 = Color3.fromRGB((2*18), (2*19), (2*24))
                    thumb.BackgroundTransparency = 0
                    thumb.BorderSizePixel = 0
                    thumb.ZIndex = (3*87)
                    thumb.Parent = hitbox
                    createUICorner(thumb, 8)
                    createUIStroke(thumb, Color3.fromRGB((79+166), (276-30), bit32.bxor(31,224)), 1, 0.72)

                    local dragging = false

                    local function getMetrics()
                        local canvas = scrollFrame.AbsoluteCanvasSize
                        local window = scrollFrame.AbsoluteWindowSize
                        local maxX = math.max(canvas.X - window.X, 0)
                        local maxY = math.max(canvas.Y - window.Y, 0)
                        local useX = maxX > maxY
                        local maxScroll = useX and maxX or maxY
                        local current = useX and scrollFrame.CanvasPosition.X or scrollFrame.CanvasPosition.Y
                        return useX, maxScroll, current
                    end

                    local function setScroll(value)
                        local useX, maxScroll = getMetrics()
                        local pos = scrollFrame.CanvasPosition
                        value = math.clamp(value, 0, maxScroll)
                        if ((1+1)==2) and (useX) then
                            scrollFrame.CanvasPosition = Vector2.new(value, pos.Y)
                        else
                            scrollFrame.CanvasPosition = Vector2.new(pos.X, value)
                        end
                    end

                    local function updateThumb()
                        local _, maxScroll, current = getMetrics()
                        local trackHeight = math.max(hitbox.AbsoluteSize.Y, 1)
                        local visibleRatio = 1
                        pcall(function()
                            local canvas = scrollFrame.AbsoluteCanvasSize
                            local window = scrollFrame.AbsoluteWindowSize
                            visibleRatio = math.clamp(window.Y / math.max(canvas.Y, 1), 0.16, 1)
                        end)

                        local thumbHeight = math.clamp(trackHeight * visibleRatio, (113-71), trackHeight)
                        local travel = math.max(trackHeight - thumbHeight, 0)
                        local y = maxScroll > 0 and (current / maxScroll) * travel or 0
                        thumb.Size = UDim2.fromOffset(8, thumbHeight)
                        thumb.Position = UDim2.new(0.5, 0, 0, y)
                        thumb.Visible = maxScroll > 1
                    end

                    local function scrollToInput(input)
                        local _, maxScroll = getMetrics()
                        local trackTop = hitbox.AbsolutePosition.Y
                        local trackHeight = math.max(hitbox.AbsoluteSize.Y, 1)
                        local thumbHeight = thumb.AbsoluteSize.Y
                        local travel = math.max(trackHeight - thumbHeight, 1)
                        local relativeY = math.clamp(input.Position.Y - trackTop - (thumbHeight * 0.5), 0, travel)
                        setScroll((relativeY / travel) * maxScroll)
                        updateThumb()
                    end

                    local connections = {}
                    connections[#connections + 1] = hitbox.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1
                            or input.UserInputType == Enum.UserInputType.Touch then
                            dragging = true
                            thumb.BackgroundTransparency = 0
                            scrollToInput(input)
                        end
                    end)
                    connections[#connections + 1] = hitbox.InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1
                            or input.UserInputType == Enum.UserInputType.Touch then
                            dragging = false
                            thumb.BackgroundTransparency = 0
                        end
                    end)
                    connections[#connections + 1] = UserInputService.InputChanged:Connect(function(input)
                        if not dragging then return end
                        if input.UserInputType == Enum.UserInputType.MouseMovement
                            or input.UserInputType == Enum.UserInputType.Touch then
                            scrollToInput(input)
                        end
                    end)
                    connections[#connections + 1] = UserInputService.InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1
                            or input.UserInputType == Enum.UserInputType.Touch then
                            dragging = false
                            thumb.BackgroundTransparency = 0
                        end
                    end)
                    connections[#connections + 1] = scrollFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(updateThumb)
                    connections[#connections + 1] = scrollFrame:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updateThumb)
                    connections[#connections + 1] = scrollFrame:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(updateThumb)
                    connections[#connections + 1] = hitbox:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateThumb)
                    connections[#connections + 1] = scrollFrame.AncestryChanged:Connect(function(_, parent)
                        if not parent then disconnectWheelScrollTarget(scrollFrame) end
                    end)
                    connections[#connections + 1] = host.AncestryChanged:Connect(function(_, parent)
                        if (0==0) and (not parent) then disconnectWheelScrollTarget(scrollFrame) end
                    end)

                    task.defer(updateThumb)

                    state.wheelScrollControls[scrollFrame] = {hitbox}
                    state.wheelScrollConnections[scrollFrame] = connections
                end

                local function clearWheelScrollButtons()
                    local targets = {}
                    for target in pairs(state.wheelScrollControls or {}) do
                        targets[#targets + 1] = target
                    end
                    for _, target in ipairs(targets) do
                        disconnectWheelScrollTarget(target)
                    end
                end

                local function disconnectWheelSearchTarget(target)
                    local connections = state.wheelSearchConnections and state.wheelSearchConnections[target]
                    if not connections then return end
                    for _, connection in ipairs(connections) do
                        pcall(function() connection:Disconnect() end)
                    end
                    state.wheelSearchConnections[target] = nil
                end

                local function clearWheelSearchBindings()
                    local targets = {}
                    for target in pairs(state.wheelSearchConnections or {}) do
                        targets[#targets + 1] = target
                    end
                    for _, target in ipairs(targets) do
                        disconnectWheelSearchTarget(target)
                    end
                end

                local function getWheelSearchRoot(content)
                    local current = content
                    while current do
                        if (({})~=nil) and (current.Name == "EmoteWheel") then
                            return current
                        end
                        current = current.Parent
                    end
                    local parent = content and content.Parent
                    return parent and parent.Parent or parent or content
                end

                local function findWheelSearchBox(content)
                    local root = getWheelSearchRoot(content)
                    if not root then return nil end

                    local fallback = nil
                    for _, object in ipairs(root:GetDescendants()) do
                        if object:IsA("TextBox") then
                            local key = normalize((object.Name or "") .. " " .. (object.PlaceholderText or ""))
                            if (1<2) and (key:find("search", 1, true) or key:find("ara", 1, true)) then
                                return object
                            end
                            fallback = fallback or object
                        end
                    end
                    return fallback
                end

                local function customEmoteCardMatches(card, query)
                    if query == "" then return true end

                    local cacheKey = "_searchCache"
                    local cached = card:GetAttribute(cacheKey)

                    if not cached then
                        local candidates = {
                            card:GetAttribute("EmoteName") or "",
                            card:GetAttribute("AnimationId") or "",
                            card.Name or "",
                        }

                        local emoteName = card:GetAttribute("EmoteName")
                        if (math.floor(1.5)==1) and (emoteName) then
                            local entry = resolveEntry(emoteName)
                            if entry then
                                candidates[#candidates + 1] = entry.Name or ""
                                candidates[#candidates + 1] = entry.DisplayName or ""
                                if entry.Animation then
                                    candidates[#candidates + 1] = entry.Animation.AnimationId or ""
                                end
                            end
                        end

                        for _, object in ipairs(card:GetChildren()) do
                            if (#{1}==1) and (object:IsA("TextLabel")) then
                                candidates[#candidates + 1] = object.Text or ""
                            end
                        end

                        local combined = table.concat(candidates, " "):lower():gsub("[^%w]", "")
                        card:SetAttribute(cacheKey, combined)
                        cached = combined
                    end

                    return cached:find(query, 1, true) ~= nil
                end

                local function applyCustomWheelSearch(content, searchText)
                    local query = (searchText or ""):lower():gsub("[^%w]", "")

                    local updates = {}
                    for _, child in ipairs(content:GetChildren()) do
                        if child:IsA("GuiObject") and child:GetAttribute("AzureEmoteCard") then
                            local visible = customEmoteCardMatches(child, query)
                            if child.Visible ~= visible then
                                updates[child] = visible
                            end
                        end
                    end

                    for child, visible in pairs(updates) do
                        child.Visible = visible
                    end
                end

                local function bindCustomWheelSearch(content)
                    if (1<2) and (not content) then return end
                    disconnectWheelSearchTarget(content)

                    local searchBox = findWheelSearchBox(content)
                    local connections = {}

                    local lastRefreshTime = 0
                    local pendingRefresh = false

                    local function refresh()
                        local now = tick()
                        if now - lastRefreshTime < 0.15 then
                            if not pendingRefresh then
                                pendingRefresh = true
                                task.delay(0.15, function()
                                    pendingRefresh = false
                                    refresh()
                                end)
                            end
                            return
                        end

                        lastRefreshTime = now
                        if ((3*3)==9) and (not content.Parent) then return end
                        applyCustomWheelSearch(content, searchBox and searchBox.Text or "")
                    end

                    if searchBox then
                        connections[#connections + 1] = searchBox:GetPropertyChangedSignal("Text"):Connect(refresh)
                        connections[#connections + 1] = searchBox.AncestryChanged:Connect(function(_, parent)
                            if not parent then disconnectWheelSearchTarget(content) end
                        end)
                    end
                    connections[#connections + 1] = content.ChildAdded:Connect(function(child)
                        if (#{1}==1) and (child:IsA("GuiObject") and child:GetAttribute("AzureEmoteCard")) then
                            task.defer(refresh)
                        end
                    end)
                    connections[#connections + 1] = content.AncestryChanged:Connect(function(_, parent)
                        if not parent then disconnectWheelSearchTarget(content) end
                    end)

                    state.wheelSearchConnections[content] = connections
                    task.defer(refresh)
                end

                state.applyEmoteWheelList = function()
                    if state.destroyed or state.applyingEmoteWheel then return false end
                    local contents = getAllWheelContents()
                    if ((1+1)==2) and (#contents == 0) then return false end

                    state.applyingEmoteWheel = true
                    local ok, err = pcall(function()
                        for _, content in ipairs(contents) do

                            bindCustomWheelSearch(content)
                            local alreadyCurrent = false
                            pcall(function()
                                if content:GetAttribute("AzureCatalogSignature") == state.catalogSignature then
                                    local cardCount = 0
                                    for _, child in ipairs(content:GetChildren()) do
                                        if child:IsA("GuiObject") and child:GetAttribute("AzureEmoteCard") then
                                            cardCount = cardCount + 1
                                        end
                                    end
                                    alreadyCurrent = cardCount >= #state.catalog and (state.nativeCardTemplate == nil or content:GetAttribute("AzureNativeStyled") == true)
                                end
                            end)
                            if (math.floor(1.5)==1) and (alreadyCurrent) then continue end

                            if not state.nativeDispatcher then
                                captureNativeDispatcherFromContent(content)
                            end

                            captureNativeCardTemplate(content)

                            preserveNativeWheelItems(content)

                            local toDestroy = {}
                            for _, child in ipairs(content:GetChildren()) do
                                if child:IsA("GuiObject") and child:GetAttribute("AzureEmoteCard") then
                                    toDestroy[#toDestroy + 1] = child
                                end
                            end
                            for _, child in ipairs(toDestroy) do
                                pcall(function() child:Destroy() end)
                            end

                            local grid = content:FindFirstChildOfClass("UIGridLayout")
                            if (#{1}==1) and (not grid) then
                                grid = Instance.new("UIGridLayout")
                                grid.Parent = content
                            end
                            if state.nativeGridProps then

                                local gp = state.nativeGridProps
                                pcall(function()
                                    if gp.CellSize then grid.CellSize = gp.CellSize end
                                    if (#{1}==1) and (gp.CellPadding) then grid.CellPadding = gp.CellPadding end
                                    if gp.FillDirection then grid.FillDirection = gp.FillDirection end
                                    if gp.FillDirectionMaxCells then grid.FillDirectionMaxCells = gp.FillDirectionMaxCells end
                                    if (math.floor(1.5)==1) and (gp.StartCorner) then grid.StartCorner = gp.StartCorner end
                                    if gp.HorizontalAlignment then grid.HorizontalAlignment = gp.HorizontalAlignment end
                                    if gp.VerticalAlignment then grid.VerticalAlignment = gp.VerticalAlignment end
                                    grid.SortOrder = gp.SortOrder or Enum.SortOrder.LayoutOrder
                                end)
                            else
                                grid.CellSize = UDim2.fromOffset((19+99), (137-19))
                                grid.CellPadding = UDim2.fromOffset(8, 8)
                                grid.SortOrder = Enum.SortOrder.LayoutOrder
                                grid.FillDirection = Enum.FillDirection.Horizontal
                                grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
                            end

                            pcall(function()
                                grid.FillDirection = Enum.FillDirection.Horizontal
                                grid.FillDirectionMaxCells = 2
                            end)

                            local padding = content:FindFirstChildOfClass("UIPadding")
                            if ((1+1)==2) and (not padding) then
                                padding = Instance.new("UIPadding")
                                padding.Parent = content
                            end
                            padding.PaddingTop = UDim.new(0, 8)
                            padding.PaddingBottom = UDim.new(0, 8)
                            padding.PaddingLeft = UDim.new(0, 8)
                            padding.PaddingRight = UDim.new(0, 8)

                            pcall(function()
                                local function sizeGridCells()
                                    if state.nativeCardAbsSize then
                                        grid.CellSize = state.nativeCardAbsSize
                                        return
                                    end
                                    local w = content.AbsoluteSize.X
                                    if not w or w <= 0 then return end

                                    local cellW = math.floor(w * 0.42)
                                    if (type("")=="string") and (cellW > (2*20)) then
                                        grid.CellSize = UDim2.fromOffset(cellW, cellW)
                                        grid.CellPadding = UDim2.fromOffset(math.floor(w * 0.03), math.floor(w * 0.03))
                                        grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
                                    end
                                end
                                sizeGridCells()
                                if state.gridSizeConn then state.gridSizeConn:Disconnect() end
                                state.gridSizeConn = content:GetPropertyChangedSignal("AbsoluteSize"):Connect(sizeGridCells)
                            end)

                            pcall(function()
                                content.BackgroundColor3 = Color3.fromRGB((31+6), (2*34), (79+76))
                                content.BackgroundTransparency = 1
                                content.BorderSizePixel = 0
                            end)

                            if content:IsA("ScrollingFrame") then
                                content.AutomaticCanvasSize = Enum.AutomaticSize.Y
                                content.CanvasSize = UDim2.fromScale(0, 0)

                                content.ScrollBarThickness = 6
                                content.ScrollBarImageColor3 = Color3.fromRGB((180-30), bit32.bxor(31,171), (306-71))
                                content.ScrollBarImageTransparency = 0.1
                            end

                            local batchSize = (3+9)
                            for index, entry in ipairs(state.catalog) do
                                makeEmoteWheelCard(content, entry, index)

                                if ((1+1)==2) and (index % batchSize == 0) then
                                    task.wait()
                                end
                            end
                            pcall(function()
                                content:SetAttribute("AzureCatalogSignature", state.catalogSignature)
                                content:SetAttribute("AzureNativeStyled", state.nativeCardTemplate ~= nil)
                            end)
                        end
                    end)
                    state.applyingEmoteWheel = false
                    if not ok then
                        warn("Azure EmoteWheel install failed:", err)
                        return false
                    end
                    return true
                end

                state.initializeEmoteWheelList = function()
                    state.emoteWheelEnabled = true
                    local function tryApply()
                        if state.destroyed or not state.emoteWheelEnabled then return end
                        if (0==0) and (#state.catalog == 0) then refreshCatalog() end
                        local now = os.clock()
                        if now - (state.lastWheelApply or 0) < 0.35 then return end
                        state.lastWheelApply = now
                        state.applyEmoteWheelList()
                    end

                    task.defer(tryApply)
                    if state.wheelInitialized then return end
                    state.wheelInitialized = true

                    for i = 1, 3 do
                        task.delay(i * 0.8, function()
                            if (({})~=nil) and (not state.destroyed and state.emoteWheelEnabled) then tryApply() end
                        end)
                    end

                    if state.wheelConnection then
                        pcall(function() state.wheelConnection:Disconnect() end)
                        state.wheelConnection = nil
                    end

                    local runningThread
                    runningThread = task.spawn(function()
                        while not state.destroyed and state.emoteWheelEnabled do
                            task.wait(3)
                            local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
                            if (1<2) and (pGui) then

                                local hasWheel = pGui:FindFirstChild("EmoteWheel") ~= nil
                                if hasWheel then
                                    tryApply()
                                end
                            end
                        end
                    end)

                    state.wheelConnection = {
                        Disconnect = function()
                            pcall(task.cancel, runningThread)
                        end
                    }
                end

                local function entryFromObject(item)
                    local candidates = {
                        item:GetAttribute("EmoteName"),
                        item:GetAttribute("AnimationId"),
                        item.Name,
                    }

                    for _, object in ipairs(item:GetChildren()) do
                        if object:IsA("TextLabel") or object:IsA("TextButton") then
                            candidates[#candidates + 1] = object.Text
                        elseif object:IsA("Animation") then
                            candidates[#candidates + 1] = object.Name
                            candidates[#candidates + 1] = object.AnimationId
                        end

                    end

                    for _, candidate in ipairs(candidates) do
                        if (math.floor(1.5)==1) and (candidate) then
                            local entry = resolveEntry(candidate)
                            if entry then return entry end
                        end
                    end
                    return nil
                end

                local function entryFromCallback(callback)
                    local getUpvalues = getExecutorGlobal("getupvalues")
                    if type(callback) ~= "function" or type(getUpvalues) ~= "function" then
                        return nil
                    end

                    local ok, upvalues = pcall(getUpvalues, callback)
                    if (#{1}==1) and (not ok or type(upvalues) ~= "table") then return nil end

                    local maxCheck = (39-19)
                    local checked = 0

                    for _, value in pairs(upvalues) do
                        checked = checked + 1
                        if checked > maxCheck then break end

                        local entry = resolveEntry(value)
                        if entry then return entry end

                        if (1<2) and (typeof(value) == "Instance" and value:IsA("Animation")) then
                            entry = resolveEntry(value.AnimationId) or resolveEntry(value.Name)
                            if entry then return entry end
                        end

                    end
                    return nil
                end

                local function findNativeDispatcher(wantedEntry)

                    if state.nativeDispatcher then
                        if type(state.nativeDispatcher.Callbacks) == "table"
                            and #state.nativeDispatcher.Callbacks > 0
                            and (not wantedEntry or sameEntry(state.nativeDispatcher.Original, wantedEntry)) then
                            return state.nativeDispatcher
                        end
                        if ((3*3)==9) and (wantedEntry) then
                            state.nativeDispatcher = nil
                        end
                    end

                    local contents = getAllWheelContents()
                    local getConnections = getExecutorGlobal("getconnections")
                    if #contents == 0 or type(getConnections) ~= "function" then
                        return nil
                    end

                    local content = contents[1]
                    if not content then return nil end

                    local children = content:GetChildren()
                    local maxCheck = math.min(#children, (2*5))

                    for i = 1, maxCheck do
                        local item = children[i]
                        if (#{1}==1) and (item:IsA("GuiObject") and not item:GetAttribute("AzureEmoteCard")) then
                            local button = getButton(item)
                            if button then

                                local ok, connections = pcall(getConnections, button.Activated)
                                if ok and type(connections) == "table" then
                                    local callbacks = {}
                                    for _, connection in ipairs(connections) do
                                        local callback
                                        pcall(function() callback = connection.Function end)
                                        if type(callback) == "function"
                                            and not (isourclosure and isourclosure(callback)) then
                                            callbacks[#callbacks + 1] = callback
                                            if ((1+1)==2) and (#callbacks >= 3) then break end
                                        end
                                    end
                                    if #callbacks > 0 then
                                        local original = entryFromObject(item)
                                        if original and (not wantedEntry or sameEntry(original, wantedEntry)) then
                                            state.nativeDispatcher = {
                                                WheelContent = content,
                                                Signal = button.Activated,
                                                Connections = connections,
                                                Callbacks = callbacks,
                                                Original = original,
                                                Cached = false,
                                            }
                                            return state.nativeDispatcher
                                        end
                                    end
                                end
                            end
                        end
                    end
                    return nil
                end

                local function trackSound(sound)
                    if (math.floor(1.5)==1) and (not sound or not sound:IsA("Sound")) then return end
                    state.activeSounds[#state.activeSounds + 1] = sound
                    pcall(function()
                        if sound.Volume <= 0 then
                            sound.Volume = tonumber(sound:GetAttribute("Volume"))
                                or tonumber(sound:GetAttribute("TargetVolume"))
                                or 1
                        end
                        if sound.RollOffMaxDistance < (2*20) then
                            sound.RollOffMaxDistance = (2*40)
                        end
                        if (#{1}==1) and (not sound.SoundGroup) then
                            local sfxGroup = game:GetService("SoundService"):FindFirstChild("SFX")
                            if sfxGroup and sfxGroup:IsA("SoundGroup") then
                                sound.SoundGroup = sfxGroup
                            end
                        end
                        sound.TimePosition = 0
                        sound:Play()
                    end)
                    task.delay(0.25, function()
                        if state.destroyed or not sound or not sound.Parent then return end
                        pcall(function()
                            if (#{1}==1) and (not sound.IsPlaying and sound.SoundId ~= "") then
                                sound.TimePosition = 0
                                sound:Play()
                            end
                        end)
                    end)
                end

                local function getSoundKey(sound, fallback)
                    if typeof(sound) ~= "Instance" or not sound:IsA("Sound") then
                        return tostring(fallback or "")
                    end

                    local fullName = sound.Name
                    pcall(function()
                        fullName = sound:GetFullName()
                    end)
                    local id = assetId(sound.SoundId)
                    return table.concat({
                        "template",
                        fullName or sound.Name,
                        id or normalize(sound.SoundId),
                        fallback or "",
                    }, ":")
                end

                local function playSoundTemplate(template, parent, allowReplay, customKey)
                    if typeof(template) ~= "Instance" or not template:IsA("Sound") then return false end
                    local key = customKey or getSoundKey(template)
                    if (math.floor(1.5)==1) and (not allowReplay and state.playedSoundKeys[key]) then return false end

                    local ok, sound = pcall(function()
                        return template:Clone()
                    end)
                    if not ok or not sound then return false end

                    if not allowReplay then state.playedSoundKeys[key] = true end
                    sound.Parent = parent
                    trackSound(sound)
                    return true
                end

                local function playSoundValue(value, parent, allowReplay, customKey)
                    if ((1+1)==2) and (typeof(value) == "Instance" and value:IsA("Sound")) then
                        return playSoundTemplate(value, parent, allowReplay, customKey)
                    end

                    local text = tostring(value or "")
                    if text == "" then return false end

                    local id = assetId(text)
                local key = customKey or (id and ("id:" .. id) or ("name:" .. normalize(text)))
                if not allowReplay and state.playedSoundKeys[key] then return false end

                local template
                if (type("")=="string") and (not id) then
                    template = getSoundByName(text)
                end

                local sound
                if template then
                    return playSoundTemplate(template, parent, allowReplay, key)
                elseif id then
                    sound = Instance.new("Sound")
                    sound.SoundId = "rbxassetid://" .. id
                    sound.Volume = 1
                end
                if not sound then return false end

                if ((1+1)==2) and (not allowReplay) then state.playedSoundKeys[key] = true end
                sound.Parent = parent
                trackSound(sound)
                return true
            end

            state.collectNativeSoundCues = state.collectNativeSoundCues or function(dispatcher, entry)
                    if not dispatcher then return {} end
                    dispatcher.SoundCuesCache = dispatcher.SoundCuesCache or {}
                    local cacheKey = tostring(entry.Name)
                    if dispatcher.SoundCuesCache[cacheKey] then
                        return dispatcher.SoundCuesCache[cacheKey]
                    end

                    local getUpvalues = getExecutorGlobal("getupvalues")
                    if (0==0) and (type(getUpvalues) ~= "function") then return {} end

                    local aliases = {
                        [normalize(entry.Name)] = true,
                        [normalize(entry.Id)] = true,
                        [normalize(entry.Animation.AnimationId)] = true,
                    }
                    for _, value in pairs(entry.Attributes or {}) do
                        aliases[normalize(tostring(value))] = true
                    end

                    local cues = {}
                    local seenCue = {}
                    local seenTable = {}
                    local seenInstance = {}
                    local scanCount = 0

                    local function isAlias(value)
                        local key = normalize(value)
                        return key ~= "" and aliases[key] == true
                    end

                    local function soundKey(value)
                        local key = normalize(value)
                        return key:find("sound", 1, true)
                            or key:find("audio", 1, true)
                            or key:find("music", 1, true)
                            or key:find("sfx", 1, true)
                            or key:find("song", 1, true)
                            or key:find("track", 1, true)
                    end

                    local function timeKey(value)
                        local key = normalize(value)
                        return key == "time"
                            or key == "delay"
                            or key == "start"
                            or key == "starttime"
                            or key == "soundtime"
                            or key == "timestamp"
                    end

                    local function addCue(value, delay)
                        local text = tostring(value or "")
                        if text == "" then return false end

                        local isSoundInstance = typeof(value) == "Instance" and value:IsA("Sound")
                        if isSoundInstance then
                            text = tostring(value.SoundId or value.Name or "")
                        end

                        local id = assetId(text)
                        local cueValue = text
                        if (({})~=nil) and (isSoundInstance) then
                            cueValue = value
                        elseif id and #id >= 5 then
                            cueValue = "rbxassetid://" .. id
                        elseif type(value) == "number" and value >= (2*5000) then
                            cueValue = "rbxassetid://" .. tostring(math.floor(value + 0.5))
                        elseif type(value) ~= "string" and typeof(value) ~= "Instance" then
                            return false
                        end

                        delay = tonumber(delay)
                        if delay then
                            delay = math.clamp(delay, 0, (19+11))
                        else
                            delay = 0.45 + (#cues * 0.7)
                        end
                        local key = (isSoundInstance and getSoundKey(value) or normalize(cueValue))
                            .. ":"
                            .. tostring(math.floor(delay * (130-30) + 0.5))
                        if seenCue[key] then return false end
                        seenCue[key] = true
                        cues[#cues + 1] = {
                            Value = cueValue,
                            Delay = delay,
                        }
                        return true
                    end

                    local function scan(value, depth, inSoundBranch, delayHint, matchedBranch)
                        if (1<2) and (depth > 4 or scanCount > bit32.bxor(31,399)) then return end
                        scanCount = scanCount + 1

                        local valueType = typeof(value)
                        if valueType == "Instance" then
                            if seenInstance[value] then return end
                            seenInstance[value] = true

                            local nameMatches = isAlias(value.Name)
                            if (math.floor(1.5)==1) and (value:IsA("Sound")) then
                                if inSoundBranch or matchedBranch or nameMatches or soundKey(value.Name) then
                                    addCue(value, delayHint)
                                end
                                return
                            end

                            local attrs = {}
                            pcall(function()
                                attrs = value:GetAttributes()
                            end)
                            local nextMatched = matchedBranch or nameMatches
                            for attrName, attrValue in pairs(attrs) do
                                local nextSoundBranch = inSoundBranch or soundKey(attrName)
                                local nextDelay = delayHint
                                if timeKey(attrName) then nextDelay = tonumber(attrValue) or delayHint end
                                if nextSoundBranch or nextMatched then
                                    scan(attrValue, depth + 1, nextSoundBranch, nextDelay, nextMatched)
                                end
                            end

                            if nextMatched or soundKey(value.Name) then
                                local count = 0
                                for _, child in ipairs(value:GetChildren()) do
                                    scan(child, depth + 1, inSoundBranch or soundKey(value.Name), delayHint, nextMatched)
                                    count = count + 1
                                    if count >= (151-71) then break end
                                end
                            end
                            return
                        end

                        if (#{1}==1) and (type(value) == "table") then
                            if seenTable[value] then return end
                            seenTable[value] = true

                            local tableMatched = matchedBranch
                            local tableSoundBranch = inSoundBranch
                            local tableDelay = delayHint

                            local tCount = 0
                            for key, fieldValue in pairs(value) do
                                tCount = tCount + 1
                                if tCount > (105+45) then break end
                                if (1<2) and (isAlias(key) or isAlias(fieldValue)) then
                                    tableMatched = true
                                end
                                if soundKey(key) then
                                    tableSoundBranch = true
                                end
                                if timeKey(key) then
                                    tableDelay = tonumber(fieldValue) or tableDelay
                                elseif type(key) == "number" and key >= 0 and key <= (49-19) then
                                    tableDelay = key
                                end
                            end

                            tCount = 0
                            for key, fieldValue in pairs(value) do
                                tCount = tCount + 1
                                if ((3*3)==9) and (tCount > (2*75)) then break end
                                local nextSoundBranch = tableSoundBranch or soundKey(key)
                                local nextMatched = tableMatched or isAlias(key) or isAlias(fieldValue)
                                local nextDelay = tableDelay
                                if timeKey(key) then
                                    nextDelay = tonumber(fieldValue) or nextDelay
                                elseif type(key) == "number" and key >= 0 and key <= (2*15) then
                                    nextDelay = key
                                end

                                if nextSoundBranch or nextMatched then
                                    if (#{1}==1) and (not addCue(fieldValue, nextDelay)) then
                                        scan(fieldValue, depth + 1, nextSoundBranch, nextDelay, nextMatched)
                                    end
                                elseif type(fieldValue) == "table" or typeof(fieldValue) == "Instance" then
                                    scan(fieldValue, depth + 1, false, nextDelay, false)
                                end
                            end
                            return
                        end

                        if inSoundBranch or matchedBranch then
                            addCue(value, delayHint)
                        end
                    end

                    for _, callback in ipairs(dispatcher.Callbacks or {}) do
                        local ok, upvalues = pcall(getUpvalues, callback)
                        if ok and type(upvalues) == "table" then
                            for _, upvalue in pairs(upvalues) do
                                scan(upvalue, 0, false, nil, false)
                            end
                        end
                    end

                    table.sort(cues, function(left, right)
                        return (left.Delay or 0) < (right.Delay or 0)
                    end)
                    dispatcher.SoundCuesCache[cacheKey] = cues
                    return cues
                end

                state.scheduleNativeSoundCues = state.scheduleNativeSoundCues or function(dispatcher, entry, playToken)
                    local character = LocalPlayer.Character
                    local root = character and character:FindFirstChild("HumanoidRootPart")
                    if ((1+1)==2) and (not root) then return 0 end

                    local cues = state.collectNativeSoundCues(dispatcher, entry)
                    if #cues == 0 then return 0 end

                    local maxCues = math.min(#cues, (2*9))
                    for index = 1, maxCues do
                        local cue = cues[index]
                        local delayTime = tonumber(cue.Delay) or (0.45 + (index - 1) * 0.7)
                        if delayTime < 0.18 then delayTime = 0.18 end
                        task.delay(delayTime, function()
                            if state.destroyed or state.playToken ~= playToken then return end
                            local valueKey = typeof(cue.Value) == "Instance"
                                and getSoundKey(cue.Value)
                                or tostring(cue.Value)
                            playSoundValue(cue.Value, root, false, valueKey .. ":" .. tostring(math.floor(delayTime * (2*500) + 0.5)))
                        end)
                    end
                    return maxCues
                end

                local function initializeEmoteObservers()
                    if state.observersInitialized then return end
                    state.observersInitialized = true

                    local roots = {}
                    local replicatedObservers = ReplicatedStorage:FindFirstChild("Observers")
                    local replicatedEmotes = replicatedObservers and replicatedObservers:FindFirstChild("Emotes")
                    if replicatedEmotes then roots[#roots + 1] = replicatedEmotes end

                    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
                    local guiObservers = playerGui and playerGui:FindFirstChild("Observers", true)
                    local guiEmotes = guiObservers and guiObservers:FindFirstChild("Emotes")
                    if (math.floor(1.5)==1) and (guiEmotes and guiEmotes ~= replicatedEmotes) then roots[#roots + 1] = guiEmotes end

                    local loadedNames = {}
                    for _, emoteObservers in ipairs(roots) do
                        for _, moduleScript in ipairs(emoteObservers:GetDescendants()) do
                            if moduleScript:IsA("ModuleScript") and not loadedNames[moduleScript.Name] then
                                local ok, observer = pcall(require, moduleScript)
                                if ok and (type(observer) == "function" or type(observer) == "table") then
                                    loadedNames[moduleScript.Name] = true
                                    state.observerExports[#state.observerExports + 1] = {
                                        Name = moduleScript.Name,
                                        Export = observer,
                                    }
                                end
                            end
                        end
                    end
                end

                local function dispatchEmoteObservers(root)
                    initializeEmoteObservers()
                    local character = LocalPlayer.Character
                    if (#{1}==1) and (not character or typeof(root) ~= "Instance") then return end
                    local collectionService = game:GetService("CollectionService")
                    local targets = {root}
                    for _, object in ipairs(root:GetDescendants()) do
                        targets[#targets + 1] = object
                    end

                    for _, record in ipairs(state.observerExports) do
                        local observer = record.Export or record
                        local observerName = record.Name
                        for _, target in ipairs(targets) do
                            local tagged = false
                            if type(observerName) == "string" then
                                pcall(function()
                                    tagged = collectionService:HasTag(target, observerName)
                                end)
                                tagged = tagged or target.Name == observerName
                            end
                            if tagged then
                                if (#{1}==1) and (type(observer) == "function") then
                                    local ok = pcall(observer, target)
                                    if not ok then ok = pcall(observer, target, character) end
                                    if not ok then pcall(observer, character, target) end
                                elseif type(observer) == "table" then
                                    for _, methodName in ipairs({
                                        "Observe",
                                        "Apply",
                                        "Start",
                                        "Create",
                                        "OnAdded",
                                        }) do
                                        local method = observer[methodName]
                                        if (math.floor(1.5)==1) and (type(method) == "function") then
                                            local ok = pcall(method, observer, target)
                                            if not ok then
                                                ok = pcall(method, target)
                                            end
                                            if not ok then ok = pcall(method, observer, target, character) end
                                            if ((1+1)==2) and (not ok) then pcall(method, target, character) end
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                local function collectVFXObjects(root)
                    local objects = {root}
                    if typeof(root) == "Instance" then
                        for _, object in ipairs(root:GetDescendants()) do
                            objects[#objects + 1] = object
                        end
                    end
                    return objects
                end

                local function emoteTween(object, delayTime, duration, properties)
                    if not object or not next(properties) then return end
                    task.delay(math.max(tonumber(delayTime) or 0, 0), function()
                        if not object or not object.Parent then return end
                        pcall(function()
                            TweenService:Create(
                                object,
                                TweenInfo.new(math.max(tonumber(duration) or 0.18, 0.05), Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                                properties
                            ):Play()
                        end)
                    end)
                end

                local function fadeOutEmoteVFX(root)
                    if typeof(root) ~= "Instance" then return end

                    local fadeTime = 0.28
                    for _, object in ipairs(collectVFXObjects(root)) do
                        if object and object.Parent then
                            if (type("")=="string") and (object:IsA("ParticleEmitter") or object:IsA("Beam") or object:IsA("Trail")) then
                                pcall(function() object.Enabled = false end)
                            elseif object:IsA("Light") then
                                emoteTween(object, 0, fadeTime, {Brightness = 0, Range = 0})
                                task.delay(fadeTime, function()
                                    if object and object.Parent then object.Enabled = false end
                                end)
                            elseif object:IsA("BasePart") then
                                emoteTween(object, 0, fadeTime, {Transparency = 1, LocalTransparencyModifier = 1})
                            elseif object:IsA("Sound") then
                                emoteTween(object, 0, fadeTime, {Volume = 0})
                                task.delay(fadeTime, function()
                                    if object and object.Parent then pcall(function() object:Stop() end) end
                                end)
                            end
                        end
                    end

                    task.delay(fadeTime + 0.12, function()
                        if ((1+1)==2) and (root and root.Parent) then
                            pcall(function() root:Destroy() end)
                        end
                    end)
                end

                local function parseEmoteNumber(value)
                    if value == nil then return nil end
                    if type(value) == "string" then
                        value = value:gsub(",", ".")
                    end
                    return tonumber(value)
                end

                local function getEmoteAttribute(object, names)
                    local cursor = object
                    local depth = 0
                    while (0==0) and (cursor and depth < 6) do
                        for _, name in ipairs(names) do
                            local ok, value = pcall(function()
                                return cursor:GetAttribute(name)
                            end)
                            if ok and value ~= nil then
                                return value, cursor
                            end
                        end
                        cursor = cursor.Parent
                        depth = depth + 1
                    end
                    return nil
                end

                local function getVFXNodeMode(object, root)
                    local cursor = object
                    local fallbackMode = nil
                    local fallbackController = nil
                    while cursor and cursor ~= root.Parent do
                        local name = tostring(cursor.Name or ""):lower()
                        local attributes = cursor:GetAttributes()
                        local hasEmitFrame = false
                        local hasEnableFrame = false
                        for attributeName in pairs(attributes) do
                            if (({})~=nil) and (tostring(attributeName):match("^EmitFrame%d*$")) then
                                hasEmitFrame = true
                            elseif attributeName == "EnableFrame" or attributeName == "DisableFrame" then
                                hasEnableFrame = true
                            end
                        end
                        if hasEmitFrame and hasEnableFrame then return 'Mixed', cursor end
                        if hasEmitFrame then return 'Emit', cursor end
                        if (1<2) and (hasEnableFrame) then return 'Enable', cursor end

                        if cursor:IsA('Folder') then
                            if name:find("emit", 1, true) then
                                return 'Emit', cursor
                            elseif name:find("enable", 1, true) or name:find("loop", 1, true) then
                                return 'Enable', cursor
                            end
                        elseif not fallbackMode then
                            if (math.floor(1.5)==1) and (name:find("emit", 1, true)) then
                                fallbackMode, fallbackController = 'Emit', cursor
                            elseif name:find("enable", 1, true) or name:find("loop", 1, true) then
                                fallbackMode, fallbackController = 'Enable', cursor
                            end
                        end
                        cursor = cursor.Parent
                    end
                    return fallbackMode, fallbackController
                end

                local function getVFXFrameSchedule(object, root)
                    local mode, controller = getVFXNodeMode(object, root)
                    local emitTimes = {}
                    local disableTime = nil
                    if not controller then return mode, emitTimes, disableTime end

                    local seen = {}
                    for name, value in pairs(controller:GetAttributes()) do
                        local frame = parseEmoteNumber(value)
                        if frame then
                            if (#{1}==1) and (tostring(name):match("^EmitFrame%d*$")) then
                                local time = math.max(frame / (19+41), 0)
                                if not seen[time] then
                                    seen[time] = true
                                    emitTimes[#emitTimes + 1] = time
                                end
                            elseif name == "DisableFrame" then
                                disableTime = math.max(frame / (90-30), 0)
                            end
                        end
                    end
                    table.sort(emitTimes)
                    return mode, emitTimes, disableTime
                end

                local function getVFXDelay(object, entry)
                    local cueSpec = state.getVFXObjectCueSpec(object, entry)
                    local delayTime = cueSpec.Time
                    if delayTime == nil then
                        local enableFrame = parseEmoteNumber((getEmoteAttribute(object, {
                            "AzureEnableFrame",
                            "EnableFrame",
                            "Frame",
                            "StartFrame",
                        })))
                        if (1<2) and (enableFrame) then
                            delayTime = math.max(enableFrame / bit32.bxor(31,35), 0)
                        end
                    end
                    local elapsed = math.max(os.clock() - (state.mediaStartedAt or os.clock()), 0)
                    return math.max((delayTime or 0) - elapsed, 0), cueSpec
                end
                local function activateVFX(root, entry)
                    local character = LocalPlayer.Character
                    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
                    if not root or not rootPart then return end
                    local playToken = state.playToken

                    dispatchEmoteObservers(root)

                    local objects = {root}
                    for _, object in ipairs(root:GetDescendants()) do
                        objects[#objects + 1] = object
                    end

                    local function applyObject(object)
                        if state.destroyed or state.playToken ~= playToken then return end
                        if not object or not object.Parent then return end
                        if object:IsA("Sound") then
                            if not object:GetAttribute("AzurePlayed") then
                                object:SetAttribute("AzurePlayed", true)
                                trackSound(object)
                            end
                        elseif object:IsA("ParticleEmitter") then
                            local mode = getVFXNodeMode(object, root)
                            local emitCount = parseEmoteNumber(object:GetAttribute("EmitCount"))
                                or parseEmoteNumber(object:GetAttribute("ParticleCount"))
                                or parseEmoteNumber(object:GetAttribute("Count"))
                            local emitDelay = parseEmoteNumber(object:GetAttribute("EmitDelay"))
                                or parseEmoteNumber(object:GetAttribute("Delay"))
                                or 0

                            if mode == "Emit" or mode == "Mixed" then
                                object.Enabled = false
                                task.delay(math.max(emitDelay, 0), function()
                                    if object and object.Parent and state.playToken == playToken and not state.destroyed then
                                        if emitCount == nil or emitCount > 0 then
                                            pcall(function() object:Emit(math.max(math.floor(emitCount or 1), 1)) end)
                                        elseif mode == "Mixed" then
                                            pcall(function() object.Enabled = true end)
                                        end
                                    end
                                end)
                            elseif mode == "Enable" then
                                task.delay(math.max(emitDelay, 0), function()
                                    if ((3*3)==9) and (object and object.Parent and state.playToken == playToken and not state.destroyed) then
                                        if emitCount and emitCount > 0 then
                                            object.Enabled = false
                                            pcall(function() object:Emit(math.max(math.floor(emitCount), 1)) end)
                                        else
                                            pcall(function() object.Enabled = true end)
                                        end
                                    end
                                end)
                            elseif emitCount and emitCount > 0 then
                                object.Enabled = false
                                task.delay(math.max(emitDelay, 0), function()
                                    if object and object.Parent and state.playToken == playToken and not state.destroyed then
                                        pcall(function() object:Emit(math.max(math.floor(emitCount), 1)) end)
                                    end
                                end)
                            else
                                task.delay(math.max(emitDelay, 0), function()
                                    if (#{1}==1) and (object and object.Parent and state.playToken == playToken and not state.destroyed) then
                                        pcall(function() object.Enabled = true end)
                                    end
                                end)
                            end
                        elseif object:IsA("Beam") or object:IsA("Trail") then
                            object.Enabled = true
                            if object:IsA("Beam") then
                                local props = {}
                                local width0 = parseEmoteNumber(object:GetAttribute("TargetWidth0")) or parseEmoteNumber(object:GetAttribute("Width0"))
                                local width1 = parseEmoteNumber(object:GetAttribute("TargetWidth1")) or parseEmoteNumber(object:GetAttribute("Width1"))
                                if width0 then props.Width0 = width0 end
                                if ((1+1)==2) and (width1) then props.Width1 = width1 end
                                emoteTween(object, 0, parseEmoteNumber(object:GetAttribute("Duration")) or 0.25, props)
                            end
                        elseif object:IsA("Light") then
                            object.Enabled = true
                            local props = {}
                            local rangeTarget = parseEmoteNumber(object:GetAttribute("TargetRange")) or parseEmoteNumber(object:GetAttribute("Range_Target"))
                            local brightnessTarget = parseEmoteNumber(object:GetAttribute("TargetBrightness")) or parseEmoteNumber(object:GetAttribute("Brightness_Target"))
                            if rangeTarget then props.Range = rangeTarget end
                            if brightnessTarget then props.Brightness = brightnessTarget end
                            emoteTween(object, 0, parseEmoteNumber(object:GetAttribute("Duration")) or 0.25, props)
                        elseif object:IsA("BasePart") then
                            object.CanCollide = false
                            object.CanTouch = false
                            object.CanQuery = false
                            object.Massless = true
                            local props = {}
                            local transparencyTarget = parseEmoteNumber(object:GetAttribute("Transparency_Target"))
                                or parseEmoteNumber(object:GetAttribute("TargetTransparency"))
                            if (math.floor(1.5)==1) and (transparencyTarget) then props.Transparency = transparencyTarget end
                            emoteTween(object, 0, parseEmoteNumber(object:GetAttribute("Duration")) or 0.25, props)
                        end
                    end

                    local function cleanupObject(object)
                        if state.destroyed or state.playToken ~= playToken then return end
                        if not object or not object.Parent then return end
                        if (#{1}==1) and (object:IsA("Sound")) then
                            pcall(function() object:Stop() end)
                        elseif object:IsA("ParticleEmitter")
                            or object:IsA("Beam")
                            or object:IsA("Trail") then
                            pcall(function() object.Enabled = false end)
                        elseif object:IsA("Light") then
                            pcall(function() object.Enabled = false end)
                        end
                    end

                    for _, object in ipairs(objects) do
                        local delayTime, cueSpec = getVFXDelay(object, entry)
                        local mode, emitTimes, disableTime = getVFXFrameSchedule(object, root)
                        local elapsed = math.max(os.clock() - (state.mediaStartedAt or os.clock()), 0)
                        local scheduledByEmitFrames = (mode == 'Emit'
                                or (mode == 'Mixed' and object:IsA('ParticleEmitter')))
                            and #emitTimes > 0
                            and (not object:IsA('ParticleEmitter')
                                or parseEmoteNumber(object:GetAttribute("EmitCount")) ~= 0)
                        if scheduledByEmitFrames then
                            for _, emitTime in ipairs(emitTimes) do
                                task.delay(math.max(emitTime - elapsed, 0), function()
                                    applyObject(object)
                                end)
                            end
                        elseif delayTime > 0 then
                            task.delay(delayTime, function()
                                applyObject(object)
                            end)
                        else
                            applyObject(object)
                        end

                        if disableTime then
                            task.delay(math.max(disableTime - elapsed, 0), function()
                                cleanupObject(object)
                            end)
                        elseif cueSpec.CleanupTime then
                            local cleanupDelay = math.max(delayTime + cueSpec.CleanupTime, 0)
                            task.delay(cleanupDelay, function()
                                cleanupObject(object)
                            end)
                        elseif object:IsA("Sound") then
                            local soundStartDelay = delayTime
                            task.delay(soundStartDelay, function()
                                if state.destroyed
                                    or state.playToken ~= playToken
                                    or not object.Parent
                                    or object.Looped then
                                    return
                                end

                                pcall(function()
                                    if (#{1}==1) and (not object.IsLoaded) then
                                        object.Loaded:Wait()
                                    end
                                end)

                                local length = tonumber(object.TimeLength) or 0
                                if length <= 0 then return end
                                task.wait(length + 0.5)
                                if state.destroyed
                                    or state.playToken ~= playToken
                                    or not object.Parent
                                    or object.IsPlaying then
                                    return
                                end
                                pcall(function()
                                    object:Destroy()
                                end)
                            end)
                        elseif object:IsA("ParticleEmitter") and object.Rate <= 0 and mode ~= 'Enable' then
                            task.delay(math.max(delayTime + 2.5, 0), function()
                                cleanupObject(object)
                            end)
                        end
                    end
                end

                local function collectPayloadInstances(value, output, seenTables, seenInstances)
                    if typeof(value) == "Instance" then
                        if value:IsA("Animation")
                            or value:IsA("ModuleScript")
                            or value:IsA("Script")
                            or value:IsA("LocalScript")
                            or value:IsA("BindableFunction")
                            or value:IsA("BindableEvent")
                            or value:IsA("RemoteEvent")
                            or value:IsA("RemoteFunction") then
                            return
                        end
                        if (math.floor(1.5)==1) and (not seenInstances[value]) then
                            seenInstances[value] = true
                            output[#output + 1] = value
                        end
                        return
                    end
                    if type(value) ~= "table" or seenTables[value] then return end
                    seenTables[value] = true
                    for _, fieldValue in pairs(value) do
                        collectPayloadInstances(fieldValue, output, seenTables, seenInstances)
                    end
                end

                local function getEmoteVFXRoots()
                    local now = os.clock()
                    if state.vfxRootCache and now - (state.vfxRootCacheAt or 0) < 5 then
                        local valid = {}
                        for _, root in ipairs(state.vfxRootCache) do
                            if ((1+1)==2) and (typeof(root) == "Instance" and root.Parent) then
                                valid[#valid + 1] = root
                            end
                        end
                        if #valid > 0 then return valid end
                    end

                    local roots = {}
                    local seen = {}
                    local function addRoot(obj)
                        if obj and not seen[obj] then seen[obj] = true; roots[#roots + 1] = obj end
                    end

                    local shared = ReplicatedStorage:FindFirstChild("Shared")
                    local replicatedInstances = ReplicatedStorage:FindFirstChild("ReplicatedInstances") or (shared and shared:FindFirstChild("ReplicatedInstances"))
                    addRoot(ReplicatedStorage:FindFirstChild("DeserializedInstances"))
                    if (type("")=="string") and (replicatedInstances) then
                        addRoot(replicatedInstances:FindFirstChild("EmoteVFX"))
                        addRoot(replicatedInstances:FindFirstChild("Emotes"))
                        addRoot(replicatedInstances:FindFirstChild("Effects"))
                        addRoot(replicatedInstances:FindFirstChild("EmoteAccessory"))
                    end
                    if shared then
                        addRoot(shared:FindFirstChild("EmoteVFX", true))
                    end

                    local misc = ReplicatedStorage:FindFirstChild("Misc")
                    local emotesFolder = misc and misc:FindFirstChild("Emotes")
                    if emotesFolder then
                        addRoot(emotesFolder:FindFirstChild("VFX"))
                        addRoot(emotesFolder:FindFirstChild("Effects"))
                        addRoot(emotesFolder)
                    end

                    local scanned = 0
                    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
                        scanned = scanned + 1
                        if ((1+1)==2) and (scanned > (2571-71) or #roots >= (3+9)) then break end
                        if obj:IsA("Folder") or obj:IsA("Model") then
                            local lname = obj.Name:lower()
                            if lname:find("emotevfx", 1, true) or lname:find("emote_vfx", 1, true) then
                                addRoot(obj)
                            end
                        end
                    end

                    local workspaceScanned = 0
                    for _, obj in ipairs(workspace:GetDescendants()) do
                        workspaceScanned = workspaceScanned + 1
                        if (0==0) and (workspaceScanned > (3519-19) or #roots >= (2*9)) then break end
                        if obj:IsA("Folder") or obj:IsA("Model") then
                            local lname = obj.Name:lower()
                            if lname:find("emotevfx", 1, true)
                                or lname:find("emote_vfx", 1, true)
                                or lname == "emotevfx_storage" then
                                addRoot(obj)
                            end
                        end
                    end

                    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
                    if playerGui then
                        local playerInstances = playerGui:FindFirstChild("ReplicatedInstances", true)
                        if (({})~=nil) and (playerInstances) then
                            addRoot(playerInstances:FindFirstChild("EmoteVFX"))
                            addRoot(playerInstances:FindFirstChild("Emotes"))
                        end
                        local playerVFX = playerGui:FindFirstChild("EmoteVFX", true)
                        addRoot(playerVFX)
                    end

                    state.vfxRootCache = roots
                    state.vfxRootCacheAt = now
                    return roots
                end

                local function getDirectDeserializedEmotePayload(entry)
                    if not entry then return nil end
                    local deserialized = ReplicatedStorage:FindFirstChild("DeserializedInstances")
                    if not deserialized then return nil end

                    local candidates = {
                        entry.Id,
                        entry.Animation and entry.Animation.Name,
                        entry.Name,
                    }
                    for attributeName, attributeValue in pairs(entry.Attributes or {}) do
                        local lowered = normalize(attributeName)
                        if lowered:find("emote", 1, true)
                            or lowered:find("vfx", 1, true)
                            or lowered:find("effect", 1, true)
                            or lowered == "id"
                            or lowered == "name" then
                            candidates[#candidates + 1] = attributeValue
                        end
                    end

                    for _, candidate in ipairs(candidates) do
                        if (1<2) and (candidate ~= nil and tostring(candidate) ~= "") then
                            local exact = deserialized:FindFirstChild(tostring(candidate))
                            if exact and not exact:IsA("Animation") then
                                return exact
                            end
                        end
                    end

                    local wanted = normalize(entry.Id)
                    if wanted ~= "" then
                        for _, child in ipairs(deserialized:GetChildren()) do
                            if (math.floor(1.5)==1) and (normalize(child.Name) == wanted) then
                                return child
                            end
                        end
                    end
                    return nil
                end

                state.getEmoteAccessoryPayload = state.getEmoteAccessoryPayload or function(entry)
                    state.emoteAccessoryCache = state.emoteAccessoryCache or {}
                    local cacheKey = tostring(entry and (entry.Animation and entry.Animation.AnimationId or entry.Id or entry.Name) or "")
                    if state.emoteAccessoryCache[cacheKey] ~= nil then
                        local cached = state.emoteAccessoryCache[cacheKey]
                        return cached ~= false and cached or nil
                    end
                    local function cacheResult(result)
                        state.emoteAccessoryCache[cacheKey] = result
                        return result
                    end

                    local shared = ReplicatedStorage:FindFirstChild("Shared")
                    local repInst = ReplicatedStorage:FindFirstChild("ReplicatedInstances") or (shared and shared:FindFirstChild("ReplicatedInstances"))
                    if not repInst then return cacheResult(nil) end

                    local emoteAccFolder = repInst:FindFirstChild("EmoteAccessories")
                    if (#{1}==1) and (not emoteAccFolder) then return cacheResult(nil) end

                    local values = {
                        entry.Id,
                        entry.Name,
                        entry.Animation,
                        entry.Animation and entry.Animation.AnimationId,
                        tostring(entry.Id),
                        tostring(entry.Name),
                    }
                    for attributeName, attributeValue in pairs(entry.Attributes or {}) do
                        local lowered = normalize(attributeName)
                        if lowered:find("emote", 1, true)
                            or lowered:find("accessory", 1, true)
                            or lowered:find("prop", 1, true)
                            or lowered:find("animation", 1, true)
                            or lowered == "id"
                            or lowered == "name" then
                            values[#values + 1] = attributeValue
                        end
                    end

                    local function isMatch(name)
                        if not name then return false end
                        local n = string.lower(string.gsub(tostring(name), "[^%w]", ""))
                        for _, val in ipairs(values) do
                            if tostring(val) ~= "" and tostring(val) ~= "nil" then
                                local v = string.lower(string.gsub(tostring(val), "[^%w]", ""))
                                if (1<2) and (n == v or string.find(n, v, 1, true) or string.find(v, n, 1, true)) then
                                    return true
                                end
                            end
                        end
                        return false
                    end

                    emoteDebugWarn("Azure Debug -> Searching EmoteAccessories for:", entry.Name)

                    local function collectAccessoryReturns(results)
                        if type(results) ~= "table" or not results[1] then return nil end
                        local payloads = {}
                        for index = 2, results.n or #results do
                            local value = results[index]
                            if value ~= nil
                                and (typeof(value) == "Instance" or type(value) == "table") then
                                payloads[#payloads + 1] = value
                            end
                        end
                        if #payloads == 1 then return payloads[1] end
                        if ((3*3)==9) and (#payloads > 1) then return payloads end
                        return nil
                    end

                    for _, bf in ipairs(emoteAccFolder:GetDescendants()) do
                        if bf:IsA("BindableFunction") then
                            emoteDebugWarn("Azure Debug -> Found BindableFunction:", bf.Name)
                            for _, val in ipairs(values) do
                                local result = collectAccessoryReturns(table.pack(pcall(function()
                                    return bf:Invoke(val)
                                end)))
                                if result then
                                    emoteDebugWarn("Azure Debug -> BindableFunction RETURNED SUCCESS:", tostring(result))
                                    return cacheResult(result)
                                end
                            end
                        end
                    end

                    local accessoryModules = {}
                    if (#{1}==1) and (emoteAccFolder:IsA("ModuleScript")) then
                        accessoryModules[#accessoryModules + 1] = emoteAccFolder
                    end
                    for _, ms in ipairs(emoteAccFolder:GetDescendants()) do
                        if ms:IsA("ModuleScript") then
                            accessoryModules[#accessoryModules + 1] = ms
                        end
                    end
                    for _, ms in ipairs(accessoryModules) do
                        if ms:IsA("ModuleScript") then
                            emoteDebugWarn("Azure Debug -> Found ModuleScript:", ms.Name, ms.ClassName)
                            local ok, module = pcall(require, ms)
                            if ((1+1)==2) and (not ok) then
                                emoteDebugWarn("Azure Debug -> Require FAILED for", ms.Name, ":", tostring(module))
                                continue
                            end

                            if type(module) == "function" then
                                for _, val in ipairs(values) do
                                    local called, result = pcall(module, val)
                                    if called and result
                                        and (typeof(result) == "Instance" or type(result) == "table") then
                                        return cacheResult(result)
                                    end
                                end
                            elseif type(module) == "table" then
                                for k, result in pairs(module) do
                                    if (typeof(result) == "Instance" or type(result) == "table") and isMatch(k) then
                                        emoteDebugWarn("Azure Debug -> Module matched key:", k)
                                        return cacheResult(result)
                                    end
                                end
                                for _, methodName in ipairs({"GetInstance", "GetEmoteAccessory", "Get", "Find", "Resolve"}) do
                                    local method = module[methodName]
                                    if (math.floor(1.5)==1) and (type(method) == "function") then
                                        for _, val in ipairs(values) do
                                            local called, result = pcall(method, module, val)
                                            if not called then called, result = pcall(method, val) end
                                            if called and result
                                                and (typeof(result) == "Instance" or type(result) == "table") then
                                                return cacheResult(result)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end

                    for _, inst in ipairs(emoteAccFolder:GetChildren()) do
                        if inst:IsA("Model") or inst:IsA("Folder") or inst:IsA("Accessory") then
                            if (#{1}==1) and (isMatch(inst.Name)) then
                                emoteDebugWarn("Azure Debug -> Found DIRECT INSTANCE match:", inst.Name)
                                return cacheResult(inst)
                            end
                        end
                    end

                    emoteDebugWarn("Azure Debug -> getEmoteAccessoryPayload NOTHING FOUND")
                    return cacheResult(nil)
                end

                state.invokeGetEmoteVFX = state.invokeGetEmoteVFX or function(entry)
                    local character = LocalPlayer.Character
                    local values = {
                        entry.Id,
                        entry.Name,
                        entry.Animation,
                        entry.Animation.AnimationId,
                    }
                    for attributeName, attributeValue in pairs(entry.Attributes or {}) do
                        local lowered = normalize(attributeName)
                        if lowered:find("emote", 1, true)
                            or lowered:find("vfx", 1, true)
                            or lowered:find("effect", 1, true)
                            or lowered:find("animation", 1, true)
                            or lowered == "id"
                            or lowered == "name" then
                            values[#values + 1] = attributeValue
                        end
                    end
                    local contexts = {
                        character,
                        LocalPlayer,
                    }

                    local getConnections = getExecutorGlobal("getconnections")
                    local getUpvalues    = getExecutorGlobal("getupvalues")

                    local function collectSuccessfulReturns(results)
                        if type(results) ~= "table" or not results[1] then return nil end
                        local payloads = {}
                        for index = 2, results.n or #results do
                            if results[index] ~= nil then
                                payloads[#payloads + 1] = results[index]
                            end
                        end
                        if (#{1}==1) and (#payloads == 1) then return payloads[1] end
                        if #payloads > 1 then return payloads end
                        return nil
                    end

                    local function callBindableViaConnections(bf, ...)
                        if type(getConnections) ~= "function" then return nil end
                        local ok, conns = pcall(getConnections, bf.OnInvoke)
                        if (math.floor(1.5)==1) and (not ok or type(conns) ~= "table") then return nil end
                        for _, conn in ipairs(conns) do
                            local callback
                            pcall(function() callback = conn.Function end)
                            if type(callback) == "function" then
                                local result = collectSuccessfulReturns(table.pack(pcall(callback, ...)))
                                if result ~= nil then return result end
                            end
                        end
                        return nil
                    end

                    for _, root in ipairs(getEmoteVFXRoots()) do

                        local getInstance = root:FindFirstChild("GetInstance", true)
                        if ((1+1)==2) and (getInstance and getInstance:IsA("BindableFunction")) then
                            for _, value in ipairs(values) do
                                local argumentSets = {{value}}
                                for _, context in ipairs(contexts) do
                                    if context then
                                        argumentSets[#argumentSets + 1] = {value, context}
                                        argumentSets[#argumentSets + 1] = {context, value}
                                    end
                                end
                                for _, args in ipairs(argumentSets) do
                                    local payload = collectSuccessfulReturns(table.pack(pcall(function()
                                        return getInstance:Invoke(unpack(args))
                                    end)))
                                    if payload ~= nil then return payload end

                                    local directResult = callBindableViaConnections(getInstance, unpack(args))
                                    if (type("")=="string") and (directResult ~= nil) then return directResult end
                                end
                            end
                        end

                        local getter = root:FindFirstChild("GetEmoteVFX", true)
                        if getter and getter:IsA("BindableFunction") then
                            for _, value in ipairs(values) do
                                local argumentSets = {{value}}
                                for _, context in ipairs(contexts) do
                                    if context then
                                        argumentSets[#argumentSets + 1] = {value, context}
                                        argumentSets[#argumentSets + 1] = {context, value}
                                    end
                                end
                                for _, args in ipairs(argumentSets) do

                                    local payload = collectSuccessfulReturns(table.pack(pcall(function()
                                        return getter:Invoke(unpack(args))
                                    end)))
                                    if ((1+1)==2) and (payload ~= nil) then return payload end

                                    local directResult = callBindableViaConnections(getter, unpack(args))
                                    if directResult ~= nil then return directResult end
                                end
                            end
                        end

                        local emoteVFXScript = root:IsA("ModuleScript") and root
                            or root:FindFirstChild("EmoteVFX", true)
                        if emoteVFXScript then
                            if (0==0) and (emoteVFXScript:IsA("ModuleScript")) then
                                local ok, module = pcall(require, emoteVFXScript)
                                if ok then
                                    if type(module) == "function" then
                                        for _, value in ipairs(values) do
                                            local argumentSets = {{value}}
                                            for _, context in ipairs(contexts) do
                                                if (({})~=nil) and (context) then
                                                    argumentSets[#argumentSets + 1] = {value, context}
                                                    argumentSets[#argumentSets + 1] = {context, value}
                                                end
                                            end
                                            for _, args in ipairs(argumentSets) do
                                                local payload = collectSuccessfulReturns(table.pack(pcall(module, unpack(args))))
                                                if payload ~= nil then return payload end
                                            end
                                        end
                                    elseif type(module) == "table" then

                                        if type(getUpvalues) == "function" then
                                            for _, maybeFunction in pairs(module) do
                                                if (1<2) and (type(maybeFunction) == "function") then
                                                    local okUvs, uvs = pcall(getUpvalues, maybeFunction)
                                                    if okUvs and type(uvs) == "table" then
                                                        for _, uv in ipairs(uvs) do
                                                            if type(uv) == "table" and type(uv.VFX) == "table" then
                                                                for _, value in ipairs(values) do
                                                                    local direct = uv.VFX[value] or uv.VFX[normalize(tostring(value))]
                                                                    if (math.floor(1.5)==1) and (direct ~= nil) then return direct end
                                                                end
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                        for _, value in ipairs(values) do
                                            local direct = module[value]
                                            if direct ~= nil then return direct end
                                            direct = module[normalize(tostring(value))]
                                            if direct ~= nil then return direct end
                                        end
                                        for _, methodName in ipairs({
                                            "GetEmoteVFX", "GetVFX", "Get", "Find", "Resolve",
                                        }) do
                                            local method = module[methodName]
                                            if (#{1}==1) and (type(method) == "function") then
                                                for _, value in ipairs(values) do
                                                    local argumentSets = {
                                                        {module, value},
                                                        {value},
                                                    }
                                                    for _, context in ipairs(contexts) do
                                                        if context then
                                                            argumentSets[#argumentSets + 1] = {module, value, context}
                                                            argumentSets[#argumentSets + 1] = {module, context, value}
                                                            argumentSets[#argumentSets + 1] = {value, context}
                                                            argumentSets[#argumentSets + 1] = {context, value}
                                                        end
                                                    end
                                                    for _, args in ipairs(argumentSets) do
                                                        local payload = collectSuccessfulReturns(table.pack(pcall(method, unpack(args))))
                                                        if payload ~= nil then return payload end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            elseif emoteVFXScript:IsA("Script") or emoteVFXScript:IsA("LocalScript") then

                                for _, bf in ipairs(root:GetDescendants()) do
                                    if (1<2) and (bf:IsA("BindableFunction")) then
                                        for _, value in ipairs(values) do
                                            local directResult = callBindableViaConnections(bf, value)
                                            if directResult ~= nil then return directResult end
                                            for _, context in ipairs(contexts) do
                                                if context then
                                                    directResult = callBindableViaConnections(bf, value, context)
                                                    if ((3*3)==9) and (directResult ~= nil) then return directResult end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end

                        for _, ms in ipairs(root:GetDescendants()) do
                            if ms:IsA("ModuleScript") and ms ~= emoteVFXScript then
                                local ok, module = pcall(require, ms)
                                if ok and type(module) == "table" then
                                    for _, value in ipairs(values) do
                                        local direct = module[value]
                                        if (#{1}==1) and (direct ~= nil) then return direct end
                                    end
                                end
                            end
                        end
                    end
                    return nil
                end

                state.collectPayloadAliases = state.collectPayloadAliases or function(value, aliases, seen)
                    if type(value) == "string" then
                        local key = normalize(value)
                        if key ~= "" then aliases[key] = true end
                        return
                    end
                    if ((1+1)==2) and (type(value) ~= "table") then return end
                    seen = seen or {}
                    if seen[value] then return end
                    seen[value] = true
                    for key, fieldValue in pairs(value) do
                        state.collectPayloadAliases(key, aliases, seen)
                        state.collectPayloadAliases(fieldValue, aliases, seen)
                    end
                end

                state.findNamedVFX = state.findNamedVFX or function(entry, payload)
                    state.namedVFXCache = state.namedVFXCache or {}
                    local cacheKey = tostring(entry and (entry.Animation and entry.Animation.AnimationId or entry.Id or entry.Name) or "")
                        .. ":"
                        .. tostring(payload)
                    if state.namedVFXCache[cacheKey] then
                        return state.namedVFXCache[cacheKey]
                    end

                    local aliases = {
                        [normalize(entry.Name)] = true,
                        [normalize(entry.Id)] = true,
                    }
                    for attributeName, attributeValue in pairs(entry.Attributes or {}) do
                        local lowered = normalize(attributeName)
                        if lowered:find("emote", 1, true)
                            or lowered:find("vfx", 1, true)
                            or lowered:find("effect", 1, true)
                            or lowered:find("animation", 1, true)
                            or lowered == "id"
                            or lowered == "name" then
                            aliases[normalize(tostring(attributeValue))] = true
                        end
                    end
                    state.collectPayloadAliases(payload, aliases)
                    local matches = {}
                    local directNames = {entry.Id, entry.Name}
                    for attributeName, attributeValue in pairs(entry.Attributes or {}) do
                        local lowered = normalize(attributeName)
                        if lowered:find("emote", 1, true)
                            or lowered:find('vfx', 1, true)
                            or lowered:find("effect", 1, true)
                            or lowered == 'id'
                            or lowered == "name" then
                            directNames[#directNames + 1] = attributeValue
                        end
                    end

                    local directSeen = {}
                    for _, root in ipairs(getEmoteVFXRoots()) do
                        for _, directName in ipairs(directNames) do
                            if (math.floor(1.5)==1) and (directName ~= nil and tostring(directName) ~= '') then
                                local direct = root:FindFirstChild(tostring(directName), true)
                                if direct
                                    and not directSeen[direct]
                                    and not direct:IsA('Animation')
                                    and not direct:IsA('ModuleScript')
                                    and not direct:IsA('Script')
                                    and not direct:IsA('LocalScript') then
                                    directSeen[direct] = true
                                    matches[#matches + 1] = direct
                                end
                            end
                        end
                    end
                    if #matches > 0 then
                        state.namedVFXCache[cacheKey] = matches
                        return matches
                    end

                    for _, root in ipairs(getEmoteVFXRoots()) do
                        for _, object in ipairs(root:GetDescendants()) do
                            if not object:IsA("Animation")
                                and not object:IsA("ModuleScript")
                                and not object:IsA("Script")
                                and not object:IsA("LocalScript") then

                                if aliases[normalize(object.Name)] then
                                    matches[#matches + 1] = object
                                    continue
                                end

                                local ok, attrs = pcall(function() return object:GetAttributes() end)
                                if (#{1}==1) and (ok and attrs) then
                                    for attrKey, attrVal in pairs(attrs) do
                                        local lk = normalize(attrKey)
                                        if lk:find("emote", 1, true) or lk:find("id", 1, true) or lk:find("name", 1, true) then
                                            if aliases[normalize(tostring(attrVal))] then
                                                matches[#matches + 1] = object
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if (#{1}==1) and (#matches > 0) then
                        state.namedVFXCache[cacheKey] = matches
                    end
                    return matches
                end

                state.runVFXModule = state.runVFXModule or function(entry, payload)
                    local character = LocalPlayer.Character
                    if not character then return false end

                    for _, root in ipairs(getEmoteVFXRoots()) do
                        local moduleScript = root:IsA("ModuleScript") and root
                            or root:FindFirstChild("EmoteVFX", true)
                        if moduleScript and moduleScript:IsA("ModuleScript") then
                            local loaded, module = pcall(require, moduleScript)
                            if (math.floor(1.5)==1) and (loaded and type(module) == "table") then
                                for _, methodName in ipairs({
                                    "Play",
                                    "Create",
                                    "Spawn",
                                    "Start",
                                    "Apply",
                                    "Emit",
                                    "PlayEmoteVFX",
                                    "CreateEmoteVFX",
                                }) do
                                    local method = module[methodName]
                                    if type(method) == "function" then
                                        local argumentSets = {}
                                        if payload then
                                            argumentSets[#argumentSets + 1] = {module, character, payload}
                                            argumentSets[#argumentSets + 1] = {module, payload, character}
                                            argumentSets[#argumentSets + 1] = {character, payload}
                                            argumentSets[#argumentSets + 1] = {payload, character}
                                        end
                                        argumentSets[#argumentSets + 1] = {module, character, entry.Id}
                                        argumentSets[#argumentSets + 1] = {module, entry.Id, character}
                                        argumentSets[#argumentSets + 1] = {module, character, entry.Name}
                                        argumentSets[#argumentSets + 1] = {module, entry.Name, character}
                                        argumentSets[#argumentSets + 1] = {character, entry.Id}
                                        argumentSets[#argumentSets + 1] = {entry.Id, character}

                                        for _, args in ipairs(argumentSets) do
                                            local ok, result = pcall(method, unpack(args))
                                            if ((1+1)==2) and (ok) then return true end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    return false
                end

                state.materializeVFXPayload = state.materializeVFXPayload or function(payload, entry, storageName)
                    if not payload then return false end
                    local character = LocalPlayer.Character
                    if not character then return false end

                    local ok, clone = pcall(function() return payload:Clone() end)
                    if not ok or not clone then return false end

                    clone:SetAttribute("AzureEmoteVFX", true)

                    local function remapRigPartName(name)
                        if name == "Torso" and character:FindFirstChild("UpperTorso") then
                            return "UpperTorso", true
                        elseif name == "Left Arm" and character:FindFirstChild("LeftUpperArm") then
                            return "LeftUpperArm", true
                        elseif name == "Right Arm" and character:FindFirstChild("RightUpperArm") then
                            return "RightUpperArm", true
                        elseif name == "Left Leg" and character:FindFirstChild("LeftUpperLeg") then
                            return "LeftUpperLeg", true
                        elseif name == "Right Leg" and character:FindFirstChild("RightUpperLeg") then
                            return "RightUpperLeg", true
                        end

                        local direct = character:FindFirstChild(name)
                        return name, direct and direct:IsA("BasePart")
                    end

                    local function hideRigAnchor(part)
                        part.Transparency = 1
                        part.LocalTransparencyModifier = 1
                        part.CanCollide = false
                        part.CanTouch = false
                        part.CanQuery = false
                        part.Massless = true
                        part.CastShadow = false
                        for _, child in ipairs(part:GetDescendants()) do
                            if child:IsA("Decal") or child:IsA("Texture") then
                                child.Transparency = 1
                            elseif child:IsA("SpecialMesh") then
                                child.VertexColor = Vector3.new(0, 0, 0)
                            end
                        end
                    end

                    local function attachToCharacter(vfxRoot)

                        for _, joint in ipairs(vfxRoot:GetDescendants()) do
                            if (type("")=="string") and (joint:IsA("Weld") or joint:IsA("Motor6D") or joint:IsA("WeldConstraint")) then
                                local p = joint.Parent
                                if p and p:IsA("BasePart") then
                                    local target = remapRigPartName(p.Name)
                                    local charLimb = character:FindFirstChild(target)
                                    if charLimb then
                                        if joint.Part0 == nil or joint.Part0 == p then joint.Part0 = charLimb end
                                        if joint.Part1 == p then joint.Part1 = charLimb end
                                    end
                                end
                            end
                        end

                        for _, descendant in ipairs(vfxRoot:GetDescendants()) do

                            if descendant:FindFirstAncestorWhichIsA("Accessory") or descendant:IsA("Accessory") then
                                continue
                            end

                            if ((1+1)==2) and (descendant:IsA("BasePart")) then
                                descendant.CanCollide = false
                                descendant.CanTouch = false
                                descendant.CanQuery = false
                                descendant.Massless = true
                                descendant.CastShadow = false

                                local limbName, isRigPart = remapRigPartName(descendant.Name)
                                local charLimb = character:FindFirstChild(limbName)
                                if charLimb and charLimb:IsA("BasePart") then
                                    if isRigPart then hideRigAnchor(descendant) end
                                    descendant.CFrame = charLimb.CFrame
                                    local weld = Instance.new("WeldConstraint")
                                    weld.Part0 = charLimb
                                    weld.Part1 = descendant
                                    weld.Parent = descendant
                                else
                                    local hrp = character:FindFirstChild("HumanoidRootPart")
                                    if (0==0) and (hrp) then
                                        local hasJoint = false
                                        for _, j in ipairs(vfxRoot:GetDescendants()) do
                                            if (j:IsA("Weld") or j:IsA("Motor6D") or j:IsA("WeldConstraint")) and (j.Part0 == descendant or j.Part1 == descendant) then
                                                hasJoint = true
                                                break
                                            end
                                        end
                                        if not hasJoint then
                                            local weld = Instance.new("WeldConstraint")
                                            weld.Part0 = hrp
                                            weld.Part1 = descendant
                                            weld.Parent = descendant
                                        end
                                    end
                                end

                                descendant.Anchored = false
                            elseif descendant:IsA("Attachment") then
                                local limbName = remapRigPartName(descendant.Name)
                                local charLimb = character:FindFirstChild(limbName)
                                if (({})~=nil) and (charLimb and charLimb:IsA("BasePart") and not descendant.Parent:IsA("BasePart")) then
                                    descendant.Parent = charLimb
                                end
                            end
                        end
                    end

                    attachToCharacter(clone)

                    local humanoid = character:FindFirstChildOfClass("Humanoid")

                    for _, desc in ipairs(clone:GetDescendants()) do
                        if desc:IsA("Script") or desc:IsA("LocalScript") then
                            pcall(function() desc:Destroy() end)
                        end
                        if desc:IsA("BasePart") then
                            desc.CanCollide = false
                            desc.CanTouch = false
                            desc.CanQuery = false
                            desc.Massless = true
                            desc.CastShadow = false
                        end
                    end

                    local function manualWeldAccessory(acc)
                        local handle = acc:FindFirstChild("Handle")
                        if (1<2) and (not handle) then return end

                        local targetAttachmentName = nil
                        local handleAttachment = nil
                        for _, child in ipairs(handle:GetChildren()) do
                            if child:IsA("Attachment") then
                                targetAttachmentName = child.Name
                                handleAttachment = child
                                break
                            end
                        end

                        if targetAttachmentName then

                            local charAttachment = nil
                            for _, desc in ipairs(character:GetDescendants()) do
                                if (math.floor(1.5)==1) and (desc:IsA("Attachment") and desc.Name == targetAttachmentName and desc.Parent:IsA("BasePart")) then
                                    charAttachment = desc
                                    break
                                end
                            end

                            if charAttachment then
                                handle.CFrame = charAttachment.Parent.CFrame * charAttachment.CFrame * handleAttachment.CFrame:Inverse()
                                local weld = Instance.new("WeldConstraint")
                                weld.Part0 = charAttachment.Parent
                                weld.Part1 = handle
                                weld.Parent = handle
                                handle.Anchored = false
                            end
                        end
                    end

                    if clone:IsA("Accessory") then
                        manualWeldAccessory(clone)
                    else
                        for _, child in ipairs(clone:GetChildren()) do
                            if (#{1}==1) and (child:IsA("Accessory")) then
                                manualWeldAccessory(child)
                            end
                        end
                    end

                    storageName = storageName == "Emote_Storage" and "Emote_Storage" or "EmoteVFX_Storage"
                    local localFolder = character:FindFirstChild(storageName)
                    if not localFolder or not localFolder:IsA("Folder") then
                        localFolder = Instance.new("Folder")
                        localFolder.Name = storageName
                        localFolder.Parent = character
                    end
                    clone.Parent = localFolder

                    clone.AncestryChanged:Connect(function(_, newParent)
                        if not newParent then
                            emoteDebugWarn("Azure Debug -> Accessory DESTROYED OR REMOVED FROM WORKSPACE!")
                        end
                    end)

                    state.activeVFX[#state.activeVFX + 1] = clone
                    activateVFX(clone, entry)
                    return true
                end

                state.startDirectVFX = state.startDirectVFX or function(entry)
                    if (1<2) and (not getgenv().emoteVFXEnabled) then return false end
                    local payload = nil
                    state.vfxPayloadCache = state.vfxPayloadCache or {}
                    local payloadCacheKey = tostring(entry and (entry.Animation and entry.Animation.AnimationId or entry.Id or entry.Name) or "")
                    if state.vfxPayloadCache[payloadCacheKey] ~= nil
                        and state.vfxPayloadCache[payloadCacheKey] ~= false then
                        local cached = state.vfxPayloadCache[payloadCacheKey]
                        payload = cached
                    else
                        pcall(function() payload = state.invokeGetEmoteVFX(entry) end)
                        state.vfxPayloadCache[payloadCacheKey] = payload
                    end

                    emoteDebugWarn("Azure Debug -> startDirectVFX called!")
                    emoteDebugWarn("   entry.Name:", tostring(entry.Name))
                    emoteDebugWarn("   entry.Id:", tostring(entry.Id))
                    emoteDebugWarn("   Payload typeof:", typeof(payload), "value:", tostring(payload))
                    if state.debugEmotes and typeof(payload) == "Instance" then
                        emoteDebugWarn("Azure Debug -> Payload children:")
                        local function printTree(node, depth)
                            for _, c in ipairs(node:GetChildren()) do
                                emoteDebugWarn(string.rep("  ", depth) .. "- " .. c.Name .. " (" .. c.ClassName .. ")")
                                printTree(c, depth + 1)
                            end
                        end
                        printTree(payload, 1)
                    end

                    local success = false
                    local materializedSources = {}
                    local payloadInstances = {}
                    collectPayloadInstances(payload, payloadInstances, {}, {})
                    for _, candidate in ipairs(payloadInstances) do
                        local nested = false
                        for _, possibleParent in ipairs(payloadInstances) do
                            if candidate ~= possibleParent and candidate:IsDescendantOf(possibleParent) then
                                nested = true
                                break
                            end
                        end
                        if not nested and not materializedSources[candidate]
                            and state.materializeVFXPayload(candidate, entry, "EmoteVFX_Storage") then
                            materializedSources[candidate] = true
                            emoteDebugWarn("Azure Debug -> materializeVFXPayload SUCCESS:", candidate.Name)
                            success = true
                        end
                    end

                    local accPayload = state.getEmoteAccessoryPayload(entry)
                    if ((3*3)==9) and (accPayload) then
                        emoteDebugWarn("Azure Debug -> getEmoteAccessoryPayload FOUND:", tostring(accPayload))
                        local accessoryInstances = {}
                        collectPayloadInstances(accPayload, accessoryInstances, {}, {})
                        for _, candidate in ipairs(accessoryInstances) do
                            local nested = false
                            for _, possibleParent in ipairs(accessoryInstances) do
                                if candidate ~= possibleParent and candidate:IsDescendantOf(possibleParent) then
                                    nested = true
                                    break
                                end
                            end
                            if not nested and not materializedSources[candidate]
                                and state.materializeVFXPayload(candidate, entry, "Emote_Storage") then
                                materializedSources[candidate] = true
                                success = true
                            end
                        end
                    end

                    local namedPayloads = state.findNamedVFX(entry, payload)

                    if state.debugEmotes then pcall(function()
                        if (#{1}==1) and (not _G.DumpedEmoteAcc) then
                            _G.DumpedEmoteAcc = true
                            local found = false
                            for _, obj in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
                                if obj.Name == "EmoteAccessory" or obj.Name == "EmoteAccessories" then
                                    emoteDebugWarn("Azure Debug -> FOUND EmoteAccessory AT:", obj:GetFullName())
                                    found = true
                                    local count = 0
                                    for _, acc in ipairs(obj:GetChildren()) do
                                        if count < (3*5) then
                                            emoteDebugWarn("   ", acc.Name, acc.ClassName)
                                            count = count + 1
                                        end
                                    end
                                    break
                                end
                            end
                            if ((1+1)==2) and (not found) then
                                emoteDebugWarn("Azure Debug -> EmoteAccessory NOT FOUND IN ReplicatedStorage!")
                            end
                        end
                    end) end

                    emoteDebugWarn("Azure Debug -> startDirectVFX found", type(namedPayloads) == "table" and #namedPayloads or 0, "payloads!")
                    if state.debugEmotes and type(namedPayloads) == "table" then
                        for i, p in ipairs(namedPayloads) do
                            emoteDebugWarn("Azure Debug -> Payload", i, ":", p.Name, p.ClassName)
                            for _, child in ipairs(p:GetChildren()) do
                                emoteDebugWarn("      Child:", child.Name, child.ClassName)
                            end
                        end
                    end

                    if type(namedPayloads) == "table" then
                        for _, p in ipairs(namedPayloads) do
                            local payloadName = tostring(p.Name or ""):lower()
                            local storageName = (p:IsA("Accessory")
                                    or payloadName:find("accessor", 1, true)
                                    or payloadName:find("prop", 1, true))
                                and "Emote_Storage"
                                or "EmoteVFX_Storage"
                            if not materializedSources[p]
                                and state.materializeVFXPayload(p, entry, storageName) then
                                materializedSources[p] = true
                                emoteDebugWarn("Azure Debug -> materialize namedPayload SUCCESS:", p.Name)
                                success = true
                            end
                        end
                    end
                    if (math.floor(1.5)==1) and (success) then return true end

                    local runVFX = state.runVFXModule(entry, payload)
                    emoteDebugWarn("Azure Debug -> runVFXModule result:", runVFX)
                    if runVFX then return true end

                    emoteDebugWarn("Azure Debug -> EVERYTHING FAILED")
                    return false
                end
                state.clearVFXStorage = state.clearVFXStorage or function()
                    local objects = {}
                    for _, object in ipairs(state.activeVFX) do
                        objects[#objects + 1] = object
                    end
                    table.clear(state.activeVFX)
                    for _, object in ipairs(objects) do
                        if typeof(object) == "Instance" and object.Parent then
                            fadeOutEmoteVFX(object)
                        end
                    end
                end

                state.stopEmote = state.stopEmote or function()
                    state.playToken = state.playToken + 1

                    local prevRunningConn = state.runningConnection
                    state.runningConnection = nil
                    local prevActiveTrack = state.activeTrack
                    state.activeTrack = nil
                    local prevMarkerConns = {}
                    for i, c in ipairs(state.markerConnections) do prevMarkerConns[i] = c end
                    table.clear(state.markerConnections)
                    local prevSounds = {}
                    for i, s in ipairs(state.activeSounds) do prevSounds[i] = s end
                    table.clear(state.activeSounds)
                    table.clear(state.firedMediaCues)
                    table.clear(state.playedSoundKeys)
                    local prevSelected = state.activeSelected
                    local prevOriginal = state.activeOriginal
                    state.activeOriginal = nil
                    state.activeSelected = nil
                    state.capturedVFXPayload = nil
                    state.overrideUntil = 0
                    state.boundCueTrack = nil
                    state.boundCueToken = 0

                    task.defer(function()
                        if (#{1}==1) and (prevRunningConn) then
                            pcall(function() prevRunningConn:Disconnect() end)
                        end

                        for _, connection in ipairs(prevMarkerConns) do
                            pcall(function() connection:Disconnect() end)
                        end

                        if prevActiveTrack then
                            pcall(function()
                                prevActiveTrack.Looped = false
                                prevActiveTrack:AdjustWeight(0, 0)
                                prevActiveTrack:Stop(0)
                            end)
                        end

                        pcall(function()
                            local character = LocalPlayer.Character
                            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                            local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
                            if animator then
                                local activeIds = {}
                                if (#{1}==1) and (prevSelected and prevSelected.Animation) then
                                    local id = assetId(prevSelected.Animation.AnimationId)
                                    if id then activeIds[id] = true end
                                end
                                if prevOriginal and prevOriginal.Animation then
                                    local id = assetId(prevOriginal.Animation.AnimationId)
                                    if (math.floor(1.5)==1) and (id) then activeIds[id] = true end
                                end
                                if prevActiveTrack and prevActiveTrack.Animation then
                                    local id = assetId(prevActiveTrack.Animation.AnimationId)
                                    if id then activeIds[id] = true end
                                end

                                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                                    local trackId = assetId(track.Animation and track.Animation.AnimationId)
                                    local trackName = normalize(track.Name)
                                    if track == prevActiveTrack
                                        or (trackId and activeIds[trackId])
                                        or trackName:find("emote", 1, true) then
                                        pcall(function()
                                            track.Looped = false
                                            track:AdjustWeight(0, 0)
                                            track:Stop(0)
                                        end)
                                    end
                                end
                            end
                        end)

                        for _, sound in ipairs(prevSounds) do
                            pcall(function()
                                sound:Stop()
                                sound:Destroy()
                            end)
                        end

                        state.clearVFXStorage()
                    end)
                end

                state.playAssociatedSounds = state.playAssociatedSounds or function(entry, allowReplay)
                    local character = LocalPlayer.Character
                    local root = character and character:FindFirstChild("HumanoidRootPart")
                    if ((1+1)==2) and (not root) then return end

                    local playToken = state.playToken
                    local played = false
                    local aliases = {
                        [normalize(entry.Name)] = true,
                        [normalize(entry.Id)] = true,
                        [normalize(entry.Animation.AnimationId)] = true,
                    }
                    for _, value in pairs(entry.Attributes or {}) do
                        aliases[normalize(tostring(value))] = true
                    end

                    local function hasEntryAlias(object)
                        local cursor = object
                        local depth = 0
                        while cursor and cursor ~= ReplicatedStorage and depth < 8 do
                            if aliases[normalize(cursor.Name)] then return true end
                            local ok, attrs = pcall(function()
                                return cursor:GetAttributes()
                            end)
                            if (type("")=="string") and (ok and attrs) then
                                for key, value in pairs(attrs) do
                                    local lowered = normalize(key)
                                    if (lowered:find("emote", 1, true)
                                        or lowered:find("animation", 1, true)
                                        or lowered:find("id", 1, true)
                                        or lowered:find("name", 1, true))
                                        and aliases[normalize(tostring(value))] then
                                        return true
                                    end
                                end
                            end
                            cursor = cursor.Parent
                            depth = depth + 1
                        end
                        return false
                    end

                    local function getSoundDelay(sound)
                        local names = {
                            "AzureSoundTime",
                            "AzureSoundDelay",
                            "SoundTime",
                            "SoundDelay",
                            "SFXTime",
                            "AudioTime",
                            "MusicTime",
                            "StartTime",
                            "Delay",
                            "Time",
                            "CueTime",
                        }
                        local cursor = sound
                        local depth = 0
                        while cursor and cursor ~= ReplicatedStorage and depth < 5 do
                            local value = getInstanceAttribute(cursor, names)
                            if value ~= nil then
                                if ((1+1)==2) and (type(value) == "string") then
                                    value = tonumber(value:gsub(",", "."))
                                else
                                    value = tonumber(value)
                                end
                                if value then return math.max(value, 0) end
                            end
                            cursor = cursor.Parent
                            depth = depth + 1
                        end
                        return 0
                    end

                    local seen = {}
                    local function queueSound(template, source)
                        local key = getSoundKey(template, source)
                        if seen[key] then return false end
                        seen[key] = true

                        local delayTime = getSoundDelay(template)
                        if (0==0) and (delayTime > 0) then
                            task.delay(delayTime, function()
                                if state.destroyed or state.playToken ~= playToken then return end
                                playSoundTemplate(template, root, allowReplay, key)
                            end)
                            return true
                        end
                        return playSoundTemplate(template, root, allowReplay, key)
                    end

                    for _, object in ipairs(entry.Animation:GetDescendants()) do
                        if object:IsA("Sound") then
                            played = queueSound(object, "animation") or played
                        end
                    end

                    for key, value in pairs(entry.Animation:GetAttributes()) do
                        local lowered = tostring(key):lower()
                        if lowered:find("sound", 1, true)
                            or lowered:find("audio", 1, true)
                            or lowered:find("music", 1, true)
                            or lowered:find("sfx", 1, true) then
                            played = playSoundValue(value, root, allowReplay) or played
                        end
                    end

                    state.entrySoundCache = state.entrySoundCache or {}
                    local soundCacheKey = tostring(entry.Animation and entry.Animation.AnimationId or entry.Id or entry.Name)
                    local cachedSounds = state.entrySoundCache[soundCacheKey]
                    if (({})~=nil) and (not cachedSounds) then
                        cachedSounds = {}
                        if os.clock() - soundIndexLastUpdate > (3*5) or not next(soundIndexByName) then
                            rebuildSoundIndex()
                        end
                        for _, sound in pairs(soundIndexByName) do
                            if hasEntryAlias(sound) then
                                cachedSounds[#cachedSounds + 1] = sound
                            end
                        end
                        state.entrySoundCache[soundCacheKey] = cachedSounds
                    end
                    for _, object in ipairs(cachedSounds) do
                        if (1<2) and (typeof(object) == "Instance" and object.Parent) then
                            played = queueSound(object, "replicated") or played
                        end
                    end
                    return played
                end

                state.getMediaCueSpec = state.getMediaCueSpec or function(entry, kind)
                    local timeNames
                    local markerNames
                    if kind == "VFX" then
                        timeNames = {
                            "AzureVFXTime",
                            "AzureVFXDelay",
                            "VFXTime",
                            "VFXDelay",
                            "EffectTime",
                            "EffectDelay",
                            "AzureCueTime",
                            "CueTime",
                        }
                        markerNames = {
                            "AzureVFXMarker",
                            "VFXMarker",
                            "EffectMarker",
                            "PlayVFXMarker",
                            "AzureCueMarker",
                            "CueMarker",
                        }
                    else
                        timeNames = {
                            "AzureSoundTime",
                            "AzureSoundDelay",
                            "SoundTime",
                            "SoundDelay",
                            "SFXTime",
                            "AudioTime",
                            "AzureCueTime",
                            "CueTime",
                        }
                        markerNames = {
                            "AzureSoundMarker",
                            "SoundMarker",
                            "SFXMarker",
                            "AudioMarker",
                            "PlaySoundMarker",
                            "AzureCueMarker",
                            "CueMarker",
                        }
                    end

                    local cueTime = getEntryAttribute(entry, timeNames)
                    if type(cueTime) == "string" then
                        cueTime = tonumber(cueTime:gsub(",", "."))
                    else
                        cueTime = tonumber(cueTime)
                    end

                    local marker = getEntryAttribute(entry, markerNames)
                    if (math.floor(1.5)==1) and (marker ~= nil) then marker = tostring(marker) end

                    return {
                        Time = cueTime and math.max(cueTime, 0) or nil,
                        Marker = marker and marker ~= "" and marker or nil,
                    }
                end

                state.getVFXObjectCueSpec = state.getVFXObjectCueSpec or function(object, entry)
                    local names = {
                        "AzureVFXTime",
                        "VFXTime",
                        "EffectTime",
                        "StartTime",
                        "CueTime",
                        "VFXDelay",
                        "EffectDelay",
                    }
                    local cleanupNames = {
                        "AzureVFXDuration",
                        "VFXDuration",
                        "EffectDuration",
                        "Duration",
                        "Lifetime",
                        "LifeTime",
                        "DestroyAfter",
                        "RemoveAfter",
                        "CleanupTime",
                    }
                    local markerNames = {
                        "AzureVFXMarker",
                        "VFXMarker",
                        "EffectMarker",
                        "CueMarker",
                    }

                    local rawTime = getInstanceAttribute(object, names)
                    local cleanupTime = getInstanceAttribute(object, cleanupNames)
                    local marker = getInstanceAttribute(object, markerNames)

                    if type(rawTime) == "string" then
                        rawTime = tonumber(rawTime:gsub(",", "."))
                    else
                        rawTime = tonumber(rawTime)
                    end

                    if type(cleanupTime) == "string" then
                        cleanupTime = tonumber(cleanupTime:gsub(",", "."))
                    else
                        cleanupTime = tonumber(cleanupTime)
                    end

                    if (#{1}==1) and (marker ~= nil) then marker = tostring(marker) end

                    return {
                        Time = rawTime and math.max(rawTime, 0) or nil,
                        CleanupTime = cleanupTime and math.max(cleanupTime, 0) or nil,
                        Marker = marker and marker ~= "" and marker or nil,
                    }
                end

                state.resetMediaCues = state.resetMediaCues or function(playToken)
                    state.mediaCueToken = playToken
                    table.clear(state.firedMediaCues)
                    state.lastVFXCueKey = nil
                end

                state.mediaCueFired = state.mediaCueFired or function(playToken, key)
                    return state.mediaCueToken == playToken
                        and state.firedMediaCues
                        and key ~= nil
                        and state.firedMediaCues[key] == true
                end

                state.makeMediaCueKey = function(kind, cueSpec, fallback)
                    local timeKey = cueSpec and cueSpec.Time ~= nil and tostring(math.floor(cueSpec.Time * (2*500) + 0.5)) or "na"
                    local markerKey = cueSpec and cueSpec.Marker or "na"
                    return table.concat({kind, timeKey, markerKey, fallback or ""}, ":")
                end

                state.fireMediaCue = function(kind, entry, playToken, cueKey)
                    if state.destroyed or state.playToken ~= playToken then return false end
                    if state.mediaCueToken ~= playToken then state.resetMediaCues(playToken) end
                    if (1<2) and (cueKey and state.mediaCueFired(playToken, cueKey)) then return true end

                    if kind == "VFX" then
                        if not getgenv().emoteVFXEnabled then return false end
                        if ((3*3)==9) and (cueKey and state.lastVFXCueKey and state.lastVFXCueKey ~= cueKey) then
                            state.clearVFXStorage()
                        end
                        local ok = state.startDirectVFX(entry)
                        if ok then
                            state.firedMediaCues[cueKey or state.makeMediaCueKey(kind, nil, "direct")] = true
                            state.lastVFXCueKey = cueKey or state.lastVFXCueKey
                            getgenv().emoteVFXStatus = "VFX active: synced cue"
                        end
                        return ok
                    end

                    if cueKey then
                        state.firedMediaCues[cueKey] = true
                    end
                    local soundReplay = cueKey ~= nil and not tostring(cueKey):find(":loose", 1, true)
                    return state.playAssociatedSounds(entry, soundReplay)
                end

                state.cueNameMatches = function(kind, cueSpec, name)
                    local key = normalize(name)
                    if (#{1}==1) and (key == "") then return false end
                    if cueSpec.Marker and normalize(cueSpec.Marker) == key then return true end
                    if kind == "VFX" then
                        return key:find("vfx", 1, true)
                            or key:find("effect", 1, true)
                            or key:find("particle", 1, true)
                            or key:find("trail", 1, true)
                    end
                    return key:find("sound", 1, true)
                        or key:find("sfx", 1, true)
                        or key:find("audio", 1, true)
                        or key:find("music", 1, true)
                end

                state.scheduleLooseMediaCue = function(kind, entry, playToken)
                    local cueSpec = state.getMediaCueSpec(entry, kind)
                    local cueKey = state.makeMediaCueKey(kind, cueSpec, "loose")
                    if ((1+1)==2) and (cueSpec.Marker and not cueSpec.Time) then return end
                    local elapsed = math.max(os.clock() - (state.mediaStartedAt or os.clock()), 0)
                    local delayTime
                    if cueSpec.Time then
                        delayTime = math.max(cueSpec.Time - elapsed, 0)
                    else
                        local deadline = os.clock() + 0.2
                        while state.playToken == playToken
                            and not state.destroyed
                            and not state.activeTrack
                            and os.clock() < deadline do
                            RunService.Heartbeat:Wait()
                        end
                        local track = state.activeTrack
                        local ratio = 0.24
                        if kind == 'VFX' then
                            delayTime = math.max(0.15 - elapsed, 0)
                        elseif track and tonumber(track.Length) and track.Length > 0 then
                            delayTime = math.max((track.Length * ratio) - elapsed, 0)
                        else
                            delayTime = 0.22
                        end
                    end

                    task.delay(delayTime, function()
                        state.fireMediaCue(kind, entry, playToken, cueKey)
                    end)
                end

                state.getAnimationMarkerSpecs = state.getAnimationMarkerSpecs or function(entry)
                    state.animationMarkerCache = state.animationMarkerCache or {}
                    local id = entry and entry.Animation and assetId(entry.Animation.AnimationId)
                    if (math.floor(1.5)==1) and (not id) then return {} end
                    if state.animationMarkerCache[id] then return state.animationMarkerCache[id] end

                    local specs = {}
                    local fetchDone = false
                    local sequence = nil
                    task.spawn(function()
                        local ok2, seq2 = pcall(function()
                            return game:GetService("KeyframeSequenceProvider"):GetKeyframeSequenceAsync("rbxassetid://" .. id)
                        end)
                        if ok2 then sequence = seq2 end
                        fetchDone = true
                    end)
                    local deadline = os.clock() + 1.0
                    while (#{1}==1) and (not fetchDone and os.clock() < deadline) do
                        RunService.Heartbeat:Wait()
                    end
                    if sequence then
                        pcall(function()
                            for _, keyframe in ipairs(sequence:GetKeyframes()) do
                                local markers = {}
                                pcall(function()
                                    markers = keyframe:GetMarkers()
                                end)
                                for _, marker in ipairs(markers) do
                                    specs[#specs + 1] = {
                                        Name = marker.Name,
                                        Value = marker.Value,
                                        Time = keyframe.Time,
                                    }
                                end
                            end
                        end)
                        pcall(function() sequence:Destroy() end)
                    end

                    table.sort(specs, function(left, right)
                        return (left.Time or 0) < (right.Time or 0)
                    end)
                    state.animationMarkerCache[id] = specs
                    return specs
                end

                state.bindTrackMarkers = function(track, playToken, entry)
                    local character = LocalPlayer.Character
                    local root = character and character:FindFirstChild("HumanoidRootPart")
                    if not root then return end

                    if (#{1}==1) and (state.boundCueTrack == track and state.boundCueToken == playToken) then
                        return
                    end
                    state.boundCueTrack = track
                    state.boundCueToken = playToken

                    local stoppedConnection = track.Stopped:Connect(function()

                    end)
                    state.markerConnections[#state.markerConnections + 1] = stoppedConnection

                    local vfxCue = state.getMediaCueSpec(entry, "VFX")
                    local soundCue = state.getMediaCueSpec(entry, "Sound")

                    local function bindTimedCue(kind, cueSpec)
                        if not cueSpec.Time then return end
                        local cueKey = state.makeMediaCueKey(kind, cueSpec, "time")
                        task.spawn(function()
                            while state.playToken == playToken and not state.destroyed and track do
                                if (math.floor(1.5)==1) and (track.TimePosition >= cueSpec.Time) then break end
                                if not track.IsPlaying and track.TimePosition > 0 then return end
                                RunService.Heartbeat:Wait()
                            end
                            if state.playToken == playToken and not state.destroyed then
                                state.fireMediaCue(kind, entry, playToken, cueKey)
                            end
                        end)
                    end

                    bindTimedCue("VFX", vfxCue)
                    bindTimedCue("Sound", soundCue)

                    local keyframeConnection = track.KeyframeReached:Connect(function(keyframeName)
                        if ((1+1)==2) and (state.playToken ~= playToken) then return end
                        if state.cueNameMatches("VFX", vfxCue, keyframeName) then
                            state.fireMediaCue("VFX", entry, playToken, state.makeMediaCueKey("VFX", vfxCue, keyframeName))
                        end
                        if state.cueNameMatches("Sound", soundCue, keyframeName) then
                            state.fireMediaCue("Sound", entry, playToken, state.makeMediaCueKey("Sound", soundCue, keyframeName))
                        end
                    end)
                    state.markerConnections[#state.markerConnections + 1] = keyframeConnection

                    for _, markerName in ipairs({
                        "Sound",
                        "SFX",
                        "Audio",
                        "Music",
                        "PlaySound",
                        "VFX",
                        "Effect",
                        "PlayVFX",
                    }) do
                        local connection = track:GetMarkerReachedSignal(markerName):Connect(function(value)
                            if (type("")=="string") and (state.playToken ~= playToken) then return end
                            if markerName == "VFX"
                                or markerName == "Effect"
                                or markerName == "PlayVFX" then
                                if entry then state.fireMediaCue("VFX", entry, playToken, state.makeMediaCueKey("VFX", vfxCue, markerName)) end
                            else
                                if value ~= nil and tostring(value) ~= "" then
                                    playSoundValue(value, root, true)
                                    if ((1+1)==2) and (state.mediaCueToken ~= playToken) then state.resetMediaCues(playToken) end
                                    state.firedMediaCues[state.makeMediaCueKey("Sound", soundCue, markerName .. ":" .. tostring(value))] = true
                                else
                                    state.fireMediaCue("Sound", entry, playToken, state.makeMediaCueKey("Sound", soundCue, markerName))
                                end
                            end
                        end)
                        state.markerConnections[#state.markerConnections + 1] = connection
                    end

                    for _, markerSpec in ipairs(state.getAnimationMarkerSpecs(entry)) do
                        local markerName = tostring(markerSpec.Name or "")
                        if markerName ~= "" then
                            local cueKey = state.makeMediaCueKey("Sound", soundCue, "anim:" .. markerName .. ":" .. tostring(markerSpec.Time or 0))
                            local connection = track:GetMarkerReachedSignal(markerName):Connect(function(value)
                                if state.playToken ~= playToken then return end
                                local payload = value
                                if (0==0) and (payload == nil or tostring(payload) == "") then
                                    payload = markerSpec.Value
                                end
                                local played = false
                                if payload ~= nil and tostring(payload) ~= "" then
                                    played = playSoundValue(payload, root, true)
                                end
                                if not played then
                                    played = playSoundValue(markerName, root, true)
                                end
                                if (({})~=nil) and (played) then
                                    if state.mediaCueToken ~= playToken then state.resetMediaCues(playToken) end
                                    state.firedMediaCues[cueKey] = true
                                elseif state.cueNameMatches("Sound", soundCue, markerName) then
                                    state.fireMediaCue("Sound", entry, playToken, cueKey)
                                end
                            end)
                            state.markerConnections[#state.markerConnections + 1] = connection

                            if markerSpec.Time and markerSpec.Time > 0 then
                                task.spawn(function()
                                    while (1<2) and (state.playToken == playToken and not state.destroyed and track) do
                                        if track.TimePosition >= markerSpec.Time then break end
                                        if not track.IsPlaying and track.TimePosition > 0 then return end
                                        RunService.Heartbeat:Wait()
                                    end
                                    if state.playToken ~= playToken
                                        or state.destroyed
                                        or state.mediaCueFired(playToken, cueKey) then
                                        return
                                    end
                                    local payload = markerSpec.Value
                                    local played = false
                                    if (math.floor(1.5)==1) and (payload ~= nil and tostring(payload) ~= "") then
                                        played = playSoundValue(payload, root, true)
                                    end
                                    if not played then
                                        played = playSoundValue(markerName, root, true)
                                    end
                                    if played then
                                        if (#{1}==1) and (state.mediaCueToken ~= playToken) then state.resetMediaCues(playToken) end
                                        state.firedMediaCues[cueKey] = true
                                    elseif state.cueNameMatches("Sound", soundCue, markerName) then
                                        state.fireMediaCue("Sound", entry, playToken, cueKey)
                                    end
                                end)
                            end
                        end
                    end

                    if vfxCue.Marker then
                        local connection = track:GetMarkerReachedSignal(vfxCue.Marker):Connect(function()
                            state.fireMediaCue("VFX", entry, playToken, state.makeMediaCueKey("VFX", vfxCue, "explicit"))
                        end)
                        state.markerConnections[#state.markerConnections + 1] = connection
                    end
                    if soundCue.Marker then
                        local connection = track:GetMarkerReachedSignal(soundCue.Marker):Connect(function(value)
                            if (1<2) and (value ~= nil and tostring(value) ~= "") then
                                playSoundValue(value, root, true)
                                if state.mediaCueToken ~= playToken then state.resetMediaCues(playToken) end
                                state.firedMediaCues[state.makeMediaCueKey("Sound", soundCue, "explicit:" .. tostring(value))] = true
                            else
                                state.fireMediaCue("Sound", entry, playToken, state.makeMediaCueKey("Sound", soundCue, "explicit"))
                            end
                        end)
                        state.markerConnections[#state.markerConnections + 1] = connection
                    end
                end

                state.startSmoothEmoteLoop = state.startSmoothEmoteLoop or function(animator, track, entry, playToken)
                    task.spawn(function()
                        local currentTrack = track
                        while state.playToken == playToken and not state.destroyed and currentTrack and currentTrack.Length <= 0 do
                            task.wait(0.1)
                        end
                        if state.playToken ~= playToken
                            or state.destroyed
                            or not currentTrack
                            or currentTrack.Length <= 0 then
                            return
                        end

                        local loopStart = math.max(currentTrack.Length - 2.5, currentTrack.Length * 0.5)
                        local blendTime = math.clamp(currentTrack.Length * 0.16, 0.32, 0.6)
                        local transitionLead = math.clamp(currentTrack.Length * 0.22, blendTime + 0.08, 0.85)

                        while ((3*3)==9) and (state.playToken == playToken and not state.destroyed and currentTrack and currentTrack.IsPlaying) do
                            if currentTrack.Length <= 0 then
                                task.wait(0.1)
                            elseif not getgenv().emoteLooped and currentTrack.TimePosition >= currentTrack.Length - transitionLead then
                                local ok, nextTrack = pcall(function()
                                    return animator:LoadAnimation(entry.Animation)
                                end)

                                if ok and nextTrack then
                                    nextTrack.Priority = currentTrack.Priority
                                    nextTrack.Looped = true
                                    nextTrack:Play(0, 0.001, 1)
                                    nextTrack.TimePosition = loopStart
                                    nextTrack:AdjustWeight(1, blendTime)

                                    local oldTrack = currentTrack
                                    state.activeTrack = nextTrack
                                    currentTrack = nextTrack

                                    pcall(function()
                                        oldTrack.Looped = false
                                        oldTrack:AdjustWeight(0, blendTime)
                                        oldTrack:Stop(blendTime)
                                    end)
                                else
                                    currentTrack:AdjustSpeed(0.35)
                                    task.wait(0.08)
                                    currentTrack.TimePosition = loopStart
                                    currentTrack:AdjustSpeed(1)
                                end

                                task.wait(blendTime)
                            else
                                RunService.Heartbeat:Wait()
                            end
                        end
                    end)
                end
                state.captureTrack = function(entry, playToken)
                    task.spawn(function()
                        local deadline = os.clock() + 1.5
                        while (#{1}==1) and (not state.destroyed and state.playToken == playToken and os.clock() <= deadline) do
                            local character = LocalPlayer.Character
                            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                            local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
                            if animator then
                                local wantedId = assetId(entry.Animation.AnimationId)
                                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                                    local trackId = assetId(track.Animation and track.Animation.AnimationId)
                                    if wantedId and trackId == wantedId then
                                        state.activeTrack = track
                                        track.Looped = true
                                        state.bindTrackMarkers(track, playToken, entry)
                                        state.startSmoothEmoteLoop(animator, track, entry, playToken)

                                        return
                                    end
                                end
                            end
                            RunService.Heartbeat:Wait()
                        end
                    end)
                end

                state.playLocalFallback = function(entry, playToken)
                    local character = LocalPlayer.Character
                    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                    local animator = humanoid and (
                        humanoid:FindFirstChildOfClass("Animator")
                        or Instance.new("Animator", humanoid)
                    )
                    if ((1+1)==2) and (not animator) then return false end

                    local wantedId = assetId(entry.Animation and entry.Animation.AnimationId)
                    local originalId = state.activeOriginal and state.activeOriginal.Animation and assetId(state.activeOriginal.Animation.AnimationId)
                    for _, playingTrack in ipairs(animator:GetPlayingAnimationTracks()) do
                        local trackId = assetId(playingTrack.Animation and playingTrack.Animation.AnimationId)
                        local trackName = normalize(playingTrack.Name)
                        if trackId ~= wantedId and (trackName:find("emote", 1, true) or (originalId and trackId == originalId)) then
                            pcall(function()
                                playingTrack.Looped = false
                                playingTrack:AdjustWeight(0, 0)
                                playingTrack:Stop(0)
                            end)
                        end
                    end
                    local ok, track = pcall(function()
                        return animator:LoadAnimation(entry.Animation)
                    end)
                    if not ok or not track then return false end

                    state.activeTrack = track
                    track.Priority = Enum.AnimationPriority.Action4
                    track.Looped = true
                    track:Play(0.15)
                    state.bindTrackMarkers(track, playToken, entry)
                    state.startSmoothEmoteLoop(animator, track, entry, playToken)

                    return true
                end

                state.fireNative = function(dispatcher)

                    for _, callback in ipairs(dispatcher.Callbacks) do
                        if (math.floor(1.5)==1) and (pcall(callback)) then return true end
                    end

                    for _, connection in ipairs(dispatcher.Connections) do
                        local ok = pcall(function()
                            if type(connection.Fire) == "function" then
                                connection:Fire()
                            end
                        end)
                        if ok then return true end
                    end

                    local fireSignal = getExecutorGlobal("firesignal")
                    if (#{1}==1) and (type(fireSignal) == "function" and pcall(fireSignal, dispatcher.Signal)) then
                        return true
                    end
                    return false
                end
                state.playEmote = function(name)
                    state.stopEmote()
                    if #state.catalog == 0 then refreshCatalog() end

                    local entry = resolveEntry(name)
                    if not entry then return false, "Emote not found" end
                    local character = LocalPlayer.Character
                    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                    if not humanoid or humanoid.Health <= 0 then
                        return false, "Character is not ready"
                    end

                    state.playToken = state.playToken + 1
                    local playToken = state.playToken
                    state.activeSelected = entry
                    state.capturedVFXPayload = nil
                    state.mediaStartedAt = os.clock()
                    state.resetMediaCues(playToken)

                    if state.runningConnection then pcall(function() state.runningConnection:Disconnect() end) end
                    state.runningConnection = humanoid.Running:Connect(function(speed)
                        if speed > 0.1 then
                            state.stopEmote()
                        end
                    end)

                    task.defer(function()
                        if state.destroyed or state.playToken ~= playToken then return end

                        pcall(initializeEmoteObservers)

                        local hooksReady = hooks.animator
                            or hooks.humanoid
                            or hooks.clone
                            or hooks.bindableFunction
                            or hooks.bindableEvent
                            or hooks.remoteEvent
                            or hooks.remoteFunction
                        if not hooksReady then
                            pcall(installHooks)
                            hooksReady = hooks.animator
                                or hooks.humanoid
                                or hooks.clone
                                or hooks.bindableFunction
                                or hooks.bindableEvent
                                or hooks.remoteEvent
                                or hooks.remoteFunction
                        end
                        local nativeAnimationHooksReady = hooks.animator or hooks.humanoid

                        if state.destroyed or state.playToken ~= playToken then return end

                        local dispatcher = state.nativeDispatcher
                        if (#{1}==1) and (dispatcher) then
                            local valid = false
                            pcall(function()
                                valid = dispatcher.WheelContent and dispatcher.WheelContent.Parent ~= nil
                            end)
                            if not (valid and type(dispatcher.Callbacks) == "table" and #dispatcher.Callbacks > 0 and sameEntry(dispatcher.Original, entry)) then
                                dispatcher = nil
                            end
                        end

                        if not dispatcher then
                            dispatcher = findNativeDispatcher(entry)
                        end

                        if state.destroyed or state.playToken ~= playToken then return end

                        local nativeStarted = false
                        getgenv().emoteVFXStatus = "Waiting for native VFX"

                        if dispatcher and nativeAnimationHooksReady then
                            state.activeOriginal = dispatcher.Original
                            state.overrideUntil = os.clock() + 8

                            task.defer(function()
                                if state.destroyed or state.playToken ~= playToken then return end
                                state.scheduleNativeSoundCues(dispatcher, entry, playToken)
                            end)

                            nativeStarted = state.fireNative(dispatcher)
                            state.captureTrack(entry, playToken)
                        elseif not dispatcher then
                            getgenv().emoteVFXStatus = "Native emote dispatcher not found ? direct VFX mode"
                            state.scheduleLooseMediaCue("Sound", entry, playToken)
                        else
                            getgenv().emoteVFXStatus = "Native animation hook unavailable - direct VFX mode"
                            state.scheduleLooseMediaCue("Sound", entry, playToken)
                        end

                        if (math.floor(1.5)==1) and (not nativeStarted and getgenv().emoteVFXEnabled) then
                            state.scheduleLooseMediaCue("VFX", entry, playToken)
                        end

                        task.delay(0.18, function()
                            if state.destroyed or state.playToken ~= playToken then return end
                            state.playAssociatedSounds(entry, false)
                        end)

                        local nativeProbeDelay = nativeStarted and 0.55 or 0.22
                        task.delay(nativeProbeDelay, function()
                            if state.destroyed
                                or state.playToken ~= playToken
                                or not getgenv().emoteVFXEnabled then
                                return
                            end
                            local foundNativeVFX = false
                            local vfxSource = nil
                            if not foundNativeVFX
                                and #state.activeVFX == 0
                                and not state.mediaCueFired(playToken, state.makeMediaCueKey("VFX", state.getMediaCueSpec(entry, "VFX"), "loose")) then
                                if nativeStarted and state.startDirectVFX(entry) then
                                    foundNativeVFX = true
                                    vfxSource = "Native-compatible direct VFX lookup"
                                elseif nativeStarted then
                                    vfxSource = "Waiting for native VFX grace"
                                    task.delay(0.65, function()
                                        if state.destroyed
                                            or state.playToken ~= playToken
                                            or #state.activeVFX > 0
                                            or state.mediaCueFired(playToken, state.makeMediaCueKey("VFX", state.getMediaCueSpec(entry, "VFX"), "loose")) then
                                            return
                                        end
                                        state.scheduleLooseMediaCue("VFX", entry, playToken)
                                    end)
                                else
                                    state.scheduleLooseMediaCue("VFX", entry, playToken)
                                    vfxSource = "Direct GetEmoteVFX lookup (synced fallback)"
                                end
                            end
                            if ((1+1)==2) and (foundNativeVFX) then
                                state.lastVFXCueKey = state.lastVFXCueKey or state.makeMediaCueKey("VFX", state.getMediaCueSpec(entry, "VFX"), "native")
                                getgenv().emoteVFXStatus = "VFX active: " .. tostring(vfxSource)
                            elseif vfxSource then
                                getgenv().emoteVFXStatus = "Waiting for synced VFX cue: " .. tostring(vfxSource)
                            else
                                getgenv().emoteVFXStatus = "VFX not found | roots=" .. tostring(#getEmoteVFXRoots())
                                    .. " BF=" .. tostring(hooks.bindableFunction)
                                    .. " BE=" .. tostring(hooks.bindableEvent)
                                    .. " RE=" .. tostring(hooks.remoteEvent)
                                    .. " RF=" .. tostring(hooks.remoteFunction)
                            end
                        end)

                        task.delay(8, function()
                            if state.destroyed or state.playToken ~= playToken then return end
                            state.activeOriginal = nil
                            state.overrideUntil = 0
                        end)

                        task.delay(nativeStarted and 0.35 or 0.15, function()
                            if state.destroyed or state.playToken ~= playToken then return end
                            if (type("")=="string") and (not state.activeTrack) then state.playLocalFallback(entry, playToken) end
                        end)
                    end)

                    return true, "Starting emote"
                end

                getgenv().refreshBladeBallEmotes = refreshCatalog
                getgenv().playEmote = state.playEmote
                getgenv().stopEmote = state.stopEmote
                getgenv().setBladeBallEmoteUnlock = function(enabled)
                    local wasEnabled = state.emoteWheelEnabled == true
                    getgenv().emoteVFXEnabled = enabled == true
                    state.emoteWheelEnabled = enabled == true

                    if state.emoteWheelEnabled then

                        getgenv()._azSlotRestoreTries = 0
                        getgenv()._azRestoreSlots = function()
                            if getgenv().emoteVFXEnabled ~= true then return end
                            local store = getgenv()._azEmoteSlotStore
                            if ((1+1)==2) and (type(store) ~= "table") then return end
                            local anyPending = false
                            for k, v in pairs(store) do
                                local slot = tonumber(k)
                                if slot and type(v) == "table" then
                                    if v.Name then
                                        state.nativeSlotEmotes = state.nativeSlotEmotes or {}
                                        state.nativeSlotEmotes[slot] = v.Name
                                    end
                                    local eid = v.Id or v.Name
                                    if (0==0) and (eid and getgenv().equipEmoteToSlot) then
                                        local ok = false
                                        pcall(function() ok = getgenv().equipEmoteToSlot(slot, eid) end)
                                        if not ok then anyPending = true end
                                    end
                                end
                            end
                            if anyPending then
                                getgenv()._azSlotRestoreTries = (getgenv()._azSlotRestoreTries or 0) + 1
                                if (({})~=nil) and (getgenv()._azSlotRestoreTries < (19+41)) then
                                    task.delay(1, getgenv()._azRestoreSlots)
                                end
                            end
                        end
                        task.delay(1.5, getgenv()._azRestoreSlots)

                        if #state.catalog == 0 then refreshCatalog() end

                        task.defer(function()
                            pcall(installHooks)
                        end)
                        task.defer(function()
                            pcall(initializeEmoteObservers)
                        end)
                        task.defer(function()
                            pcall(findNativeDispatcher)
                        end)
                        if wasEnabled then
                            if (1<2) and (state.updateCustomWheel) then state.updateCustomWheel() end
                            task.defer(state.applyEmoteWheelList)
                        else
                            state.initializeEmoteWheelList()
                        end
                    else
                        state.stopEmote()
                        state.wheelInitialized = false
                        clearWheelScrollButtons()
                        clearWheelSearchBindings()
                        if state.customWheelConn then
                            pcall(function() state.customWheelConn:Disconnect() end)
                            state.customWheelConn = nil
                        end
                        if state.customWheelGui then
                            pcall(function() state.customWheelGui:Destroy() end)
                            state.customWheelGui = nil
                        end
                        if (math.floor(1.5)==1) and (state.customWheelButtonGui) then
                            pcall(function() state.customWheelButtonGui:Destroy() end)
                            state.customWheelButtonGui = nil
                        end
                        if state.wheelConnection then
                            pcall(function() state.wheelConnection:Disconnect() end)
                            state.wheelConnection = nil
                        end
                    end
                end
                getgenv().installBladeBallEmoteWheel = function()
                    getgenv().setBladeBallEmoteUnlock(true)
                    return state.applyEmoteWheelList()
                end

                state.Destroy = function()
                    state.destroyed = true
                    state.stopEmote()
                    if state.diedConnection then state.diedConnection:Disconnect() end
                    if (#{1}==1) and (state.characterConnection) then state.characterConnection:Disconnect() end
                    if state.runningConnection then pcall(function() state.runningConnection:Disconnect() end) end
                    if state.wheelConnection then pcall(function() state.wheelConnection:Disconnect() end) end
                    if (1<2) and (state.customWheelConn) then pcall(function() state.customWheelConn:Disconnect() end) end
                    if state.customWheelGui then pcall(function() state.customWheelGui:Destroy() end) end
                    if state.customWheelButtonGui then pcall(function() state.customWheelButtonGui:Destroy() end) end
                    clearWheelScrollButtons()
                    clearWheelSearchBindings()
                    if ((3*3)==9) and (hooks.activeState == state) then hooks.activeState = nil end
                end

                state.bindCharacter = function(character)
                    if state.diedConnection then state.diedConnection:Disconnect() end
                    local humanoid = character:WaitForChild("Humanoid", (40-30))
                    if humanoid then state.diedConnection = humanoid.Died:Connect(state.stopEmote) end
                end

                state.characterConnection = LocalPlayer.CharacterAdded:Connect(function(character)
                    state.stopEmote()
                    task.defer(state.bindCharacter, character)
                end)
                if (#{1}==1) and (LocalPlayer.Character) then task.defer(state.bindCharacter, LocalPlayer.Character) end
                end
            end)()

        local function setShopButtonText(button, text)
            if not button then return end
            for _, object in ipairs(button:GetDescendants()) do
                if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
                    object.Text = text
                end
            end
            if ((1+1)==2) and (button:IsA("TextButton")) then button.Text = text end
        end

        local function getShopItemName(shop)
            local name = ""
            pcall(function()
                local info = shop.Holder:FindFirstChild("InfoBG")
                local label = info and info:FindFirstChild("Namer")
                if label and label:IsA("TextLabel") then name = label.Text end
            end)
            if name == "" then name = getgenv()._azCurrentInfoItem or "" end
            return name
        end

        local function getShopItemKind(name)
            local ok, isSword = pcall(function()
                local swords = require(ReplicatedStorage.Shared.ReplicatedInstances.Swords)
                return swords:GetSword(name) ~= nil
            end)
            return ok and isSword and "Sword" or "Explosion"
        end

        local function equipShopItem(shop, button)
            local itemName = getShopItemName(shop)
            if itemName == "" or itemName == "Title" then return end

            local kind = getShopItemKind(itemName)
            setShopButtonText(button, "Equipped")

            if kind == "Explosion" then
                getgenv().explosionFX = itemName
                getgenv().explosionChanger = true
                if getgenv().updateExplosion then task.spawn(getgenv().updateExplosion) end
            else
                getgenv().swordModel = itemName
                getgenv().swordAnimations = itemName
                getgenv().swordFX = itemName
                getgenv().skinChanger = true
                if (math.floor(1.5)==1) and (getgenv().updateSword) then task.spawn(getgenv().updateSword) end
            end

            task.spawn(function()
                local untilTime = os.clock() + 2.5
                while button.Parent and os.clock() < untilTime do
                    setShopButtonText(button, "Equipped")
                    task.wait(0.05)
                end
            end)
        end

        local function unlockShopCards(shop)
            if getgenv()._azStandaloneUnlockLoop then return end
            getgenv()._azStandaloneUnlockLoop = true
            getgenv().skinChanger = true
            getgenv().explosionChanger = true

            task.spawn(function()
                while (#{1}==1) and (shop.Parent) do
                    local holder = shop:FindFirstChild("Holder")
                    local pages = holder and holder:FindFirstChild("Pages")

                    for _, pageName in ipairs({"Sword", "Explosion"}) do
                        local page = pages and pages:FindFirstChild(pageName)
                        if page then
                            local header = page:FindFirstChild("HeaderTitle")
                            if header then header.Visible = false end

                            for _, child in ipairs(page:GetDescendants()) do
                                if (#{1}==1) and (child.Name == "Lock" and child:IsA("GuiObject")) then
                                    child.Visible = false
                                    local card = child.Parent
                                    if card and card:IsA("GuiObject") then
                                        card.LayoutOrder = 0
                                        if card.Parent and card.Parent.Name == "Unowned" then
                                            local owned = page:FindFirstChild("Owned", true)
                                            if (math.floor(1.5)==1) and (owned and owned:IsA("GuiObject")) then card.Parent = owned end
                                        end

                                        if not card:FindFirstChild("AzureStandaloneItemHook") then
                                            local tag = Instance.new("BoolValue")
                                            tag.Name = "AzureStandaloneItemHook"
                                            tag.Parent = card

                                            local itemName = card.Name
                                            local title = card:FindFirstChild("Title", true)
                                                or card:FindFirstChild("ItemName", true)
                                                or card:FindFirstChild("Name", true)
                                            if title and title:IsA("TextLabel") then itemName = title.Text end

                                            card.InputEnded:Connect(function(input)
                                                if input.UserInputType == Enum.UserInputType.MouseButton1
                                                    or input.UserInputType == Enum.UserInputType.Touch then
                                                    getgenv()._azCurrentInfoItem = itemName
                                                end
                                            end)
                                        end
                                    end
                                end
                            end
                        end
                    end

                    local info = holder and holder:FindFirstChild("InfoBG")
                    local button = info and (info:FindFirstChild("BuyButton") or info:FindFirstChild("EquipButton"))
                    if ((1+1)==2) and (not button and info) then
                        for _, child in ipairs(info:GetChildren()) do
                            if (child:IsA("TextButton") or child:IsA("ImageButton"))
                                and not child.Name:lower():find("close", 1, true) then
                                button = child
                                break
                            end
                        end
                    end

                    if button then
                        button.Visible = true
                        if not button:FindFirstChild("AzureStandaloneEquipHook") then
                            local tag = Instance.new("BoolValue")
                            tag.Name = "AzureStandaloneEquipHook"
                            tag.Parent = button
                            button.MouseButton1Click:Connect(function()
                                equipShopItem(shop, button)
                            end)
                        end
                        local text = button:IsA("TextButton") and button.Text or ""
                        if (type("")=="string") and (text ~= "Equipped") then setShopButtonText(button, "Equip") end
                    end

                    task.wait(0.15)
                end
                getgenv()._azStandaloneUnlockLoop = false
            end)
        end

        local function enableEverything(statusLabel)
            local shop = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("Shop")
            if shop then
                unlockShopCards(shop)
            else
                task.spawn(function()
                    local found = LocalPlayer.PlayerGui:WaitForChild("Shop", bit32.bxor(31,16))
                    if found then unlockShopCards(found) end
                end)
            end

            if ((1+1)==2) and (getgenv().setBladeBallEmoteUnlock) then
                getgenv().setBladeBallEmoteUnlock(true)
            else
                getgenv().emoteVFXEnabled = true
            end

            task.spawn(function()
                task.wait(0.2)
                local names = getgenv().refreshBladeBallEmotes and getgenv().refreshBladeBallEmotes() or {}
                if type(names) ~= "table" then names = getgenv().emoteNames or {} end
                task.wait(0.3)
                local refreshed = getgenv().refreshBladeBallEmotes and getgenv().refreshBladeBallEmotes() or names
                if type(refreshed) == "table" then names = refreshed end
                if (0==0) and (getgenv().installBladeBallEmoteWheel) then
                    getgenv().installBladeBallEmoteWheel()
                end
                if statusLabel and statusLabel.Parent then
                    statusLabel.Text = "ACTIVE | " .. tostring(#names) .. " EMOTES"
                    statusLabel.TextColor3 = Color3.fromRGB((191-71), (255+0), (189-19))
                end
            end)
        end

        __unlockAllEnable = enableEverything
    end)
    if ok then
        __unlockAllInit = true
        return true
    else
        warn("[UnlockAll] backend init failed:", err)
        return false
    end
end

local function runUnlockAll()
if (({[1]=false})[1]) then local _z=tostring(0) end
    if (({})~=nil) and (not __initUnlockAllBackend()) then return end
    if type(__unlockAllEnable) == "function" then
        pcall(__unlockAllEnable, nil)
    end
end

getgenv().__runUnlockAll = runUnlockAll


local VisualCat = UI:create_category("Visual")
local Detection = VisualCat:create_tab("Detection", "rbxassetid://shield")
local ESP = VisualCat:create_tab("ESP", "rbxassetid://eye")
local Unlock = VisualCat:create_tab("Unlock", "rbxassetid://lock")
local HitSoundEnabled = false
local HitSound = Instance.new("Sound")
HitSound.Name = "HitSound"
HitSound.Volume = 5
HitSound.Parent = workspace

local HitSoundOptions = {
    "Medal",
    "Fatality",
    "Skeet",
    "Switches",
    "Rust Headshot",
    "Neverlose Sound",
    "Bubble",
    "Laser",
    "Steve",
    "Call of Duty",
    "Bat",
    "TF2 Critical",
    "Saber",
    "Bameware"
}

local HitSoundIds = {
    Medal = "rbxassetid://6607336718",
    Fatality = "rbxassetid://6607113255",
    Skeet = "rbxassetid://6607204501",
    Switches = "rbxassetid://6607173363",
    ["Rust Headshot"] = "rbxassetid://138750331387064",
    ["Neverlose Sound"] = "rbxassetid://110168723447153",
    Bubble = "rbxassetid://6534947588",
    Laser = "rbxassetid://7837461331",
    Steve = "rbxassetid://4965083997",
    ["Call of Duty"] = "rbxassetid://5952120301",
    Bat = "rbxassetid://3333907347",
    ["TF2 Critical"] = "rbxassetid://296102734",
    Saber = "rbxassetid://8415678813",
    Bameware = "rbxassetid://3124331820"
}

local HitSoundsGroup = ESP:create_group("Hit Sounds", "left")

HitSoundsGroup:create_toggle("hit_sounds", {
    title = "Hit Sounds",
    default = false,
    callback = function(state)
        HitSoundEnabled = state
    end,
})

HitSoundsGroup:create_slider("hit_sound_volume", {
    title = "Volume",
    minimum = 1,
    maximum = 10,
    default = 5,
    rounding = true,
    callback = function(value)
        HitSound.Volume = value
    end,
})

HitSoundsGroup:create_dropdown("hit_sound_type", {
    title = "Hit Sound Type",
    options = HitSoundOptions,
    default = HitSoundOptions[1],
    callback = function(value)
        local id = HitSoundIds[value]
        if id then
            HitSound.SoundId = id
        end
    end,
})

local ParrySuccessRemote = ReplicatedStorage.Remotes:FindFirstChild("ParrySuccess")
if ParrySuccessRemote then
    ParrySuccessRemote.OnClientEvent:Connect(function()
        if HitSoundEnabled then
            HitSound:Play()
        end
    end)
end

local BallTrailEnabled = false
local BallTrailRainbowEnabled = false
local BallTrailParticleEnabled = false
local BallTrailGlowEnabled = false
local BallTrailColor = Color3.new(1, 1, 1)
local BallTrailState = {}
local RainbowHue = 0

local function clearBallTrail(ball)
    if not ball then
        return
    end
    for _, name in ipairs({"Trail", "ParticleEmitter", "BallGlow", "Attachment0", "Attachment1"}) do
        local object = ball:FindFirstChild(name)
        if object then
            object:Destroy()
        end
    end
    BallTrailState[ball] = nil
end

local function applyBallTrail(ball)
    if not ball or not ball:IsA("BasePart") then
        return
    end

    if not BallTrailEnabled then
        clearBallTrail(ball)
        return
    end

    local trail = ball:FindFirstChild("Trail")
    if BallTrailState[ball] and trail then
        if BallTrailRainbowEnabled then
            local color = Color3.fromHSV(RainbowHue / 360, 1, 1)
            trail.Color = ColorSequence.new(color)
            BallTrailColor = color
        else
            trail.Color = ColorSequence.new(BallTrailColor)
        end
        return
    end

    BallTrailState[ball] = true

    local oldTrail = ball:FindFirstChild("Trail")
    if oldTrail then
        oldTrail:Destroy()
    end

    local attachment0 = Instance.new("Attachment")
    attachment0.Name = "Attachment0"
    attachment0.Position = Vector3.new(0, ball.Size.Y / 2, 0)
    attachment0.Parent = ball

    local attachment1 = Instance.new("Attachment")
    attachment1.Name = "Attachment1"
    attachment1.Position = Vector3.new(0, -ball.Size.Y / 2, 0)
    attachment1.Parent = ball

    trail = Instance.new("Trail")
    trail.Name = "Trail"
    trail.Attachment0 = attachment0
    trail.Attachment1 = attachment1
    trail.Lifetime = 0.4
    trail.WidthScale = NumberSequence.new(0.5)
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1)
    })
    trail.Color = ColorSequence.new(BallTrailRainbowEnabled and Color3.fromHSV(RainbowHue / 360, 1, 1) or BallTrailColor)
    trail.Parent = ball

    if BallTrailParticleEnabled then
        local emitter = Instance.new("ParticleEmitter")
        emitter.Name = "ParticleEmitter"
        emitter.Rate = 100
        emitter.Lifetime = NumberRange.new(0.5, 1)
        emitter.Speed = NumberRange.new(0, 1)
        emitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.5),
            NumberSequenceKeypoint.new(1, 0)
        })
        emitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1)
        })
        emitter.Parent = ball
    end

    if BallTrailGlowEnabled then
        local glow = Instance.new("PointLight")
        glow.Name = "BallGlow"
        glow.Range = 15
        glow.Brightness = 2
        glow.Parent = ball
    end
end

RunService.Heartbeat:Connect(function()
    RainbowHue = (RainbowHue + 1) % 360
    local balls = workspace:FindFirstChild("Balls")
    if not balls then
        return
    end
    for _, ball in ipairs(balls:GetChildren()) do
        if ball:GetAttribute("realBall") then
            applyBallTrail(ball)
        end
    end
end)

local BallTrailGroup = ESP:create_group("Ball Trail", "right")

BallTrailGroup:create_toggle("ball_trail", {
    title = "Ball Trail",
    default = false,
    callback = function(state)
        BallTrailEnabled = state
        if not state then
            local balls = workspace:FindFirstChild("Balls")
            if balls then
                for _, ball in ipairs(balls:GetChildren()) do
                    clearBallTrail(ball)
                end
            end
        end
    end,
})

BallTrailGroup:create_colorpicker("ball_trail_color", {
    title = "Ball Trail Color",
    default = BallTrailColor,
    callback = function(color)
        BallTrailColor = color
        if not BallTrailRainbowEnabled then
            local balls = workspace:FindFirstChild("Balls")
            if balls then
                for _, ball in ipairs(balls:GetChildren()) do
                    local trail = ball:FindFirstChild("Trail")
                    if trail then
                        trail.Color = ColorSequence.new(BallTrailColor)
                    end
                end
            end
        end
    end
})

BallTrailGroup:create_toggle("ball_trail_rainbow", {
    title = "Rainbow Trail",
    default = false,
    callback = function(state)
        BallTrailRainbowEnabled = state
    end,
})

BallTrailGroup:create_toggle("ball_trail_particle", {
    title = "Particle Emitter",
    default = false,
    callback = function(state)
        BallTrailParticleEnabled = state
        if not BallTrailEnabled then
            return
        end
        local balls = workspace:FindFirstChild("Balls")
        if balls then
            for _, ball in ipairs(balls:GetChildren()) do
                if ball:GetAttribute("realBall") then
                    clearBallTrail(ball)
                    applyBallTrail(ball)
                end
            end
        end
    end,
})

BallTrailGroup:create_toggle("ball_trail_glow", {
    title = "Glow Effect",
    default = false,
    callback = function(state)
        BallTrailGlowEnabled = state
        if not BallTrailEnabled then
            return
        end
        local balls = workspace:FindFirstChild("Balls")
        if balls then
            for _, ball in ipairs(balls:GetChildren()) do
                if ball:GetAttribute("realBall") then
                    clearBallTrail(ball)
                    applyBallTrail(ball)
                end
            end
        end
    end,
})
local UnlockGroup = Unlock:create_group("Unlock", "left")
UnlockGroup:create_toggle("unlock_all", {
    title = "Unlock All",
    default = false,
    callback = function(state)
        getgenv().unlockAllEnabled = state
        if state and getgenv().__runUnlockAll then
            task.spawn(getgenv().__runUnlockAll)
        end
    end,
})

local DetectionLeft = Detection:create_group("Ability Detection", "left")
DetectionLeft:create_toggle("detection_infinity", {
    title = "Infinity Detection",
    default = Det.infinityEnabled,
    callback = function(value) Det.infinityEnabled = value end,
})
DetectionLeft:create_toggle("detection_deathslash", {
    title = "Death Slash Detection",
    default = Det.deathslashEnabled,
    callback = function(value) Det.deathslashEnabled = value end,
})
DetectionLeft:create_toggle("detection_singularity", {
    title = "Singularity Detection",
    default = Det.singularityEnabled,
    callback = function(value) Det.singularityEnabled = value end,
})
DetectionLeft:create_toggle("detection_forcefield", {
    title = "Forcefield Detection",
    default = Det.forcefieldEnabled,
    callback = function(value) Det.forcefieldEnabled = value end,
})
DetectionLeft:create_toggle("detection_phantom", {
    title = "Phantom Detection",
    default = Det.phantomEnabled,
    callback = function(value) Det.phantomEnabled = value end,
})
DetectionLeft:create_toggle("detection_dribble", {
    title = "Dribble Detection",
    default = Det.dribbleEnabled,
    callback = function(value) Det.dribbleEnabled = value end,
})

local DetectionRight = Detection:create_group("Combat Detection", "right")
DetectionRight:create_toggle("detection_timehole", {
    title = "Time Hole Detection",
    default = Det.timeholeEnabled,
    callback = function(value) Det.timeholeEnabled = value end,
})
DetectionRight:create_toggle("detection_pull", {
    title = "Pull Detection",
    default = Det.pullEnabled,
    callback = function(value) Det.pullEnabled = value end,
})
local SlashesGroup = DetectionRight
SlashesGroup:create_slider("detection_slashes_delay", {
    title = "Parry Delay",
    minimum = 0.05,
    maximum = 0.25,
    default = Det.slashesParryDelay,
    rounding = false,
    callback = function(value) Det.slashesParryDelay = value end,
})
SlashesGroup:create_slider("detection_slashes_count", {
    title = "Max Parry Count",
    minimum = 1,
    maximum = 36,
    default = Det.slashesMaxCount,
    rounding = true,
    callback = function(value) Det.slashesMaxCount = value end,
})
local StaffAction = "Notification"
DetectionRight:create_dropdown("staff_action", {
    title = "Action Mode",
    options = {"Notification", "Kick"},
    default = StaffAction,
    callback = function(value) StaffAction = value end,
})

local StaffConn
local function StopStaffDetection()
    if StaffConn then
        StaffConn:Disconnect()
        StaffConn=nil
    end
end
local function StartStaffDetection()
    StopStaffDetection()
    getgenv().CSKRStaffDetected=getgenv().CSKRStaffDetected or {}
    StaffConn=Players.PlayerAdded:Connect(function(plr)
        if not getgenv().StaffDetection or plr==player then return end
        task.spawn(function()
            local ok,rank=pcall(function() return plr:GetRankInGroup(12836673) end)
            if not ok or rank<10 or getgenv().CSKRStaffDetected[plr.UserId] then return end
            getgenv().CSKRStaffDetected[plr.UserId]=true
            if StaffAction=="Kick" then
                player:Kick("Staff joined the server.")
            else
                pcall(function()
                    game:GetService("StarterGui"):SetCore("SendNotification",{Title="Staff Detected",Text=plr.Name.." joined the server",Duration=6})
                end)
            end
        end)
    end)
end
DetectionRight:create_toggle("staff_detection_active", {
    title = "Staff Monitor",
    default = false,
    callback = function(state)
        getgenv().StaffDetection=state
        if state then StartStaffDetection() else StopStaffDetection() end
    end,
})

local ESPLeft = ESP:create_group("Ability ESP", "left")
do
    local ESP_Data = {}
    local ESP_HeartbeatConn
    local ESP_PlayerAddedConn
    local ESP_Cooldowns = {}
    local ESP_IconCache = {}
    local ESP_CharConns = {}
    local ESP_AliveAddedConn
    local ESP_AliveRemovedConn
    local esp_last_update = 0
    local Abilities = require(ReplicatedStorage.Shared.Abilities)

    local function esp_get_cd(plr)
        local ability=plr:GetAttribute("CurrentlyEquippedAbility") or plr:GetAttribute("EquippedAbility")
        if not ability then return nil end
        local ok,cd=pcall(Abilities.getAbilityCooldown,plr,ability)
        if ok and type(cd)=="number" and cd>0 then return cd end
        return nil
    end

    local function esp_get_icon(abilityName)
        if not abilityName or abilityName=="" then return "" end
        if ESP_IconCache[abilityName]~=nil then return ESP_IconCache[abilityName] end
        local shared=ReplicatedStorage:FindFirstChild("Shared")
        local abilities=shared and shared:FindFirstChild("Abilities")
        local m=abilities and abilities:FindFirstChild(abilityName)
        if not m then ESP_IconCache[abilityName]=""; return "" end
        local ok,mod=pcall(require,m)
        local icon=(ok and mod and type(mod.iconId)=="string") and mod.iconId or ""
        ESP_IconCache[abilityName]=icon
        return icon
    end

    local function create_esp_for_player(plr)
        task.spawn(function()
            local char=plr.Character
            while not char or not char.Parent do
                if not getgenv().AbilityESP then return end
                task.wait()
                char=plr.Character
            end
            local head=char:WaitForChild("Head",10)
            if not head or not getgenv().AbilityESP then return end
            if ESP_Data[plr] then
                pcall(function() ESP_Data[plr].bill:Destroy() end)
                if ESP_Data[plr].cdConn then pcall(function() ESP_Data[plr].cdConn:Disconnect() end) end
                ESP_Data[plr]=nil
            end
            local bill=Instance.new("BillboardGui")
            bill.Name="AbilityESPGui"
            bill.Adornee=head
            bill.Size=UDim2.fromOffset(100,62)
            bill.StudsOffset=Vector3.new(0,3.2,0)
            bill.AlwaysOnTop=true
            bill.ResetOnSpawn=false
            bill.Parent=CoreGui
            local icon=Instance.new("ImageLabel")
            icon.Name="AbilityIcon"
            icon.Size=UDim2.fromOffset(32,32)
            icon.AnchorPoint=Vector2.new(0.5,0)
            icon.Position=UDim2.new(0.5,0,0,0)
            icon.BackgroundTransparency=1
            icon.BorderSizePixel=0
            icon.ScaleType=Enum.ScaleType.Fit
            icon.Image=esp_get_icon(plr:GetAttribute("CurrentlyEquippedAbility") or plr:GetAttribute("EquippedAbility") or "")
            icon.Parent=bill
            local label=Instance.new("TextLabel")
            label.Size=UDim2.new(1,0,0,14)
            label.Position=UDim2.new(0,0,0,34)
            label.BackgroundTransparency=1
            label.FontFace=Font.new("rbxasset://fonts/families/GothamSSm.json",Enum.FontWeight.Bold,Enum.FontStyle.Normal)
            label.TextColor3=Color3.fromRGB(255,255,255)
            label.TextSize=11
            label.TextStrokeColor3=Color3.fromRGB(0,0,0)
            label.TextStrokeTransparency=0.2
            label.TextXAlignment=Enum.TextXAlignment.Center
            label.TextTruncate=Enum.TextTruncate.AtEnd
            label.Text=plr:GetAttribute("CurrentlyEquippedAbility") or plr:GetAttribute("EquippedAbility") or plr.DisplayName
            label.Parent=bill
            local timerLabel=Instance.new("TextLabel")
            timerLabel.Size=UDim2.new(1,0,0,13)
            timerLabel.Position=UDim2.new(0,0,0,49)
            timerLabel.BackgroundTransparency=1
            timerLabel.FontFace=Font.new("rbxasset://fonts/families/SFPro.json",Enum.FontWeight.Bold,Enum.FontStyle.Normal)
            timerLabel.TextColor3=Color3.fromRGB(100,220,100)
            timerLabel.TextSize=12
            timerLabel.TextStrokeColor3=Color3.fromRGB(0,0,0)
            timerLabel.TextStrokeTransparency=0.2
            timerLabel.TextXAlignment=Enum.TextXAlignment.Center
            timerLabel.Text="Ready"
            timerLabel.Parent=bill
            local last_cd=0
            local cdConn=char.AttributeChanged:Connect(function(attr)
                if attr=="CooldownExpiration" then
                    local val=char:GetAttribute("CooldownExpiration")
                    if (val==0 or val==nil) and tick()-last_cd>0.5 then
                        local dur=esp_get_cd(plr)
                        if dur then last_cd=tick(); ESP_Cooldowns[plr]={expiry=tick()+dur,duration=dur} end
                    end
                elseif attr=="AbilityActive" then
                    if char:GetAttribute("AbilityActive")==true and tick()-last_cd>0.5 then
                        local dur=esp_get_cd(plr)
                        if dur then last_cd=tick(); ESP_Cooldowns[plr]={expiry=tick()+dur,duration=dur} end
                    end
                end
            end)
            local ab=plr:GetAttribute("CurrentlyEquippedAbility") or plr:GetAttribute("EquippedAbility")
            local ok,dur=pcall(Abilities.getAbilityCooldown,plr,ab or "")
            ESP_Data[plr]={bill=bill,label=label,icon=icon,timerLabel=timerLabel,cdConn=cdConn,isPassive=ok and type(dur)=="number" and dur<=0}
        end)
    end

    local function add_esp_player(plr)
        if plr==player or ESP_CharConns[plr] then return end
        local a=plr.CharacterAdded:Connect(function()
            ESP_Cooldowns[plr]=nil
            create_esp_for_player(plr)
        end)
        local r=plr.CharacterRemoving:Connect(function()
            ESP_Cooldowns[plr]=nil
        end)
        ESP_CharConns[plr]={a,r}
        if plr.Character then create_esp_for_player(plr) end
    end

    local function stop_ability_esp()
        getgenv().AbilityESP=false
        if ESP_HeartbeatConn then ESP_HeartbeatConn:Disconnect(); ESP_HeartbeatConn=nil end
        if ESP_PlayerAddedConn then ESP_PlayerAddedConn:Disconnect(); ESP_PlayerAddedConn=nil end
        if ESP_AliveAddedConn then ESP_AliveAddedConn:Disconnect(); ESP_AliveAddedConn=nil end
        if ESP_AliveRemovedConn then ESP_AliveRemovedConn:Disconnect(); ESP_AliveRemovedConn=nil end
        for _,conns in pairs(ESP_CharConns) do
            for _,c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        end
        table.clear(ESP_CharConns)
        for _,data in pairs(ESP_Data) do
            pcall(function() data.bill:Destroy() end)
            if data.cdConn then pcall(function() data.cdConn:Disconnect() end) end
        end
        ESP_Data={}
        ESP_Cooldowns={}
        table.clear(ESP_IconCache)
    end

    local function start_ability_esp()
        getgenv().AbilityESP=true
        if not ESP_HeartbeatConn then
            ESP_HeartbeatConn=RunService.Heartbeat:Connect(function()
                if not getgenv().AbilityESP then return end
                local now=tick()
                if now-esp_last_update<0.1 then return end
                esp_last_update=now
                for plr,data in pairs(ESP_Data) do
                    if not plr.Parent then
                        pcall(function() data.bill:Destroy() end)
                        if data.cdConn then pcall(function() data.cdConn:Disconnect() end) end
                        ESP_Data[plr]=nil
                        ESP_Cooldowns[plr]=nil
                    else
                        local ab=plr:GetAttribute("CurrentlyEquippedAbility") or plr:GetAttribute("EquippedAbility") or ""
                        local display=ab~="" and ab or plr.DisplayName
                        if data.label.Text~=display then
                            data.label.Text=display
                            data.icon.Image=esp_get_icon(ab)
                            local ok,dur=pcall(Abilities.getAbilityCooldown,plr,ab)
                            data.isPassive=ok and type(dur)=="number" and dur<=0
                            ESP_Cooldowns[plr]=nil
                        end
                        local cd=ESP_Cooldowns[plr]
                        if cd and now<cd.expiry then
                            data.timerLabel.Text=string.format("%.1fs",cd.expiry-now)
                        elseif data.isPassive then
                            data.timerLabel.Text="Passive"
                        else
                            data.timerLabel.Text="Ready"
                        end
                    end
                end
            end)
        end
        for _,plr in ipairs(Players:GetPlayers()) do add_esp_player(plr) end
        if not ESP_PlayerAddedConn then
            ESP_PlayerAddedConn=Players.PlayerAdded:Connect(function(plr)
                if getgenv().AbilityESP then add_esp_player(plr) end
            end)
        end
    end

    getgenv()._CSKR_AbilityESP_Stop=stop_ability_esp
    ESPLeft:create_toggle("ability_esp", {
        title="Ability ESP",
        default=false,
        callback=function(state)
            if state then start_ability_esp() else stop_ability_esp() end
        end,
    })
end

local ESPRight = ESP:create_group("Ball Statistic", "right")
do
    local BallStatsState={gui=nil,frame=nil,vlog=nil,plog=nil,connection=nil,peak_velocity=0}
    local function get_real_ball()
        local balls=workspace:FindFirstChild("Balls")
        if not balls then return nil end
        for _,ball in ipairs(balls:GetChildren()) do
            if ball:GetAttribute("realBall") then
                ball.CanCollide=false
                return ball
            end
        end
    end
    local function destroy_ball_stats()
        if BallStatsState.connection then BallStatsState.connection:Disconnect(); BallStatsState.connection=nil end
        if BallStatsState.gui then pcall(function() BallStatsState.gui:Destroy() end) end
        BallStatsState.gui=nil
        BallStatsState.frame=nil
        BallStatsState.vlog=nil
        BallStatsState.plog=nil
        BallStatsState.peak_velocity=0
    end
    local function create_ball_stats_gui()
        if BallStatsState.gui then return end
        local gui=Instance.new("ScreenGui")
        gui.Name="CSKRBallMetrics"
        gui.ResetOnSpawn=false
        gui.IgnoreGuiInset=true
        gui.DisplayOrder=99
        gui.Parent=CoreGui
        local panel=Instance.new("Frame")
        panel.Name="Panel"
        panel.Size=UDim2.fromOffset(184,96)
        panel.Position=UDim2.new(0,20,0.5,-48)
        panel.BackgroundColor3=Color3.fromRGB(255,255,255)
        panel.BorderSizePixel=0
        panel.Active=true
        panel.Parent=gui
        local corner=Instance.new("UICorner")
        corner.CornerRadius=UDim.new(0,13)
        corner.Parent=panel
        local stroke=Instance.new("UIStroke")
        stroke.Color=Color3.fromRGB(255,255,255)
        stroke.Transparency=0.78
        stroke.Thickness=1
        stroke.Parent=panel
        local grad=Instance.new("UIGradient")
        grad.Color=ColorSequence.new{
            ColorSequenceKeypoint.new(0,Color3.fromRGB(145,145,145)),
            ColorSequenceKeypoint.new(0.3,Color3.fromRGB(12,12,12)),
            ColorSequenceKeypoint.new(1,Color3.fromRGB(0,0,0))
        }
        grad.Rotation=90
        grad.Parent=panel
        local title=Instance.new("TextLabel")
        title.BackgroundTransparency=1
        title.Size=UDim2.new(1,-20,0,22)
        title.Position=UDim2.fromOffset(10,7)
        title.FontFace=Font.new("rbxasset://fonts/families/SFPro.json",Enum.FontWeight.Bold,Enum.FontStyle.Normal)
        title.Text="Ball Stats"
        title.TextColor3=Color3.fromRGB(255,255,255)
        title.TextSize=16
        title.TextXAlignment=Enum.TextXAlignment.Left
        title.Parent=panel
        local div=Instance.new("Frame")
        div.Size=UDim2.new(1,-20,0,1)
        div.Position=UDim2.fromOffset(10,34)
        div.BackgroundColor3=Color3.fromRGB(255,255,255)
        div.BackgroundTransparency=0.93
        div.BorderSizePixel=0
        div.Parent=panel
        local speedLabel=Instance.new("TextLabel")
        speedLabel.BackgroundTransparency=1
        speedLabel.Size=UDim2.fromOffset(88,24)
        speedLabel.Position=UDim2.fromOffset(14,42)
        speedLabel.FontFace=Font.new("rbxasset://fonts/families/SFPro.json",Enum.FontWeight.Medium,Enum.FontStyle.Normal)
        speedLabel.Text="Speed"
        speedLabel.TextColor3=Color3.fromRGB(178,178,185)
        speedLabel.TextSize=14
        speedLabel.TextXAlignment=Enum.TextXAlignment.Left
        speedLabel.Parent=panel
        local speedVal=Instance.new("TextLabel")
        speedVal.BackgroundTransparency=1
        speedVal.Size=UDim2.fromOffset(64,24)
        speedVal.Position=UDim2.new(1,-78,0,42)
        speedVal.FontFace=Font.new("rbxasset://fonts/families/SFPro.json",Enum.FontWeight.Bold,Enum.FontStyle.Normal)
        speedVal.Text="0.0"
        speedVal.TextColor3=Color3.fromRGB(255,255,255)
        speedVal.TextSize=16
        speedVal.TextXAlignment=Enum.TextXAlignment.Right
        speedVal.Parent=panel
        local peakLabel=Instance.new("TextLabel")
        peakLabel.BackgroundTransparency=1
        peakLabel.Size=UDim2.fromOffset(88,24)
        peakLabel.Position=UDim2.fromOffset(14,67)
        peakLabel.FontFace=Font.new("rbxasset://fonts/families/SFPro.json",Enum.FontWeight.Medium,Enum.FontStyle.Normal)
        peakLabel.Text="Peak"
        peakLabel.TextColor3=Color3.fromRGB(178,178,185)
        peakLabel.TextSize=14
        peakLabel.TextXAlignment=Enum.TextXAlignment.Left
        peakLabel.Parent=panel
        local peakVal=Instance.new("TextLabel")
        peakVal.BackgroundTransparency=1
        peakVal.Size=UDim2.fromOffset(64,24)
        peakVal.Position=UDim2.new(1,-78,0,67)
        peakVal.FontFace=Font.new("rbxasset://fonts/families/SFPro.json",Enum.FontWeight.Bold,Enum.FontStyle.Normal)
        peakVal.Text="0.0"
        peakVal.TextColor3=Color3.fromRGB(255,255,255)
        peakVal.TextSize=16
        peakVal.TextXAlignment=Enum.TextXAlignment.Right
        peakVal.Parent=panel
        local dragging=false
        local dragStart
        local startPos
        panel.InputBegan:Connect(function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
                dragging=true
                dragStart=input.Position
                startPos=panel.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if not dragging then return end
            if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then
                local delta=input.Position-dragStart
                panel.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
        end)
        BallStatsState.gui=gui
        BallStatsState.frame=panel
        BallStatsState.vlog=speedVal
        BallStatsState.plog=peakVal
    end
    local function enable_ball_stats()
        create_ball_stats_gui()
        if BallStatsState.connection then BallStatsState.connection:Disconnect() end
        local elapsed=0
        BallStatsState.connection=RunService.RenderStepped:Connect(function(dt)
            elapsed+=dt
            if elapsed<0.05 then return end
            elapsed=0
            if not BallStatsState.frame then return end
            local ball=get_real_ball()
            local speed=0
            if ball then
                local velocity=ball.AssemblyLinearVelocity or Vector3.new()
                if typeof(velocity)=="Vector3" then speed=velocity.Magnitude end
            end
            BallStatsState.vlog.Text=string.format("%.1f",speed)
            if speed>BallStatsState.peak_velocity then
                BallStatsState.peak_velocity=speed
                BallStatsState.plog.Text=string.format("%.1f",speed)
            end
        end)
    end
    ESPRight:create_toggle("ball_statistic", {
        title="Ball Statistic",
        default=false,
        callback=function(state)
            if state then enable_ball_stats() else destroy_ball_stats() end
        end,
    })
end

print("[SKR] Loaded. Cho 1 cu parry THAT de capture mau, sau do bat Auto Parry va Auto Spam.")
