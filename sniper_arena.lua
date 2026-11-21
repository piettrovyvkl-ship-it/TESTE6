-- ╔══════════════════════════════════════════╗
-- ║     Systemkkj Hub — Sniper Arena v3      ║
-- ║     Silent Aim + Bot Filter + Nova UI    ║
-- ║     Executor: Mediu / KRNL / Synapse     ║
-- ╚══════════════════════════════════════════╝

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Camera           = workspace.CurrentCamera
local LP               = Players.LocalPlayer
local PGui             = LP:WaitForChild("PlayerGui")

-- ════════════════════════════════
--  CONFIG
-- ════════════════════════════════
local CFG = {
    -- Aimbot
    Aimbot        = true,
    SilentAim     = true,       -- desvia bala sem mover câmera
    AimbotKey     = Enum.KeyCode.Q,
    AimbotSmooth  = 0.18,
    AimbotFOV     = 300,
    Prediction    = true,
    PredictStr    = 0.07,
    TargetBots    = true,       -- mirar em bots também
    TargetPlayers = true,       -- mirar em players

    -- ESP
    ESP           = true,
    ESPBoxes      = true,
    ESPNames      = true,
    ESPDist       = true,
    ESPHealth     = true,
    ESPTracers    = true,
    ShowBots      = true,       -- ESP em bots
    ShowPlayers   = true,       -- ESP em players

    -- Misc
    TeamCheck     = false,
    AntiKick      = true,
    Crosshair     = true,
}

-- ════════════════════════════════
--  ANTI-KICK
-- ════════════════════════════════
if CFG.AntiKick then
    pcall(function()
        local mt  = getrawmetatable(game)
        local old = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            if getnamecallmethod() == "Kick" and self == LP then return end
            return old(self, ...)
        end)
        setreadonly(mt, true)
    end)
end

-- ════════════════════════════════
--  UTILS
-- ════════════════════════════════
local function getChar(p)  return p and p.Character end
local function getHum(c)   return c and c:FindFirstChildOfClass("Humanoid") end
local function getRoot(c)  return c and c:FindFirstChild("HumanoidRootPart") end

local function isAlive(char)
    if not char then return false end
    local h = getHum(char)
    return h and h.Health > 0
end

-- detecta se um Character é bot (NPC) ou player real
local function isBot(char)
    if not char then return false end
    local p = Players:GetPlayerFromCharacter(char)
    return p == nil   -- nil = nenhum Player dono = é NPC/bot
end

local function isEnemy(p)
    if not CFG.TeamCheck then return true end
    return p.Team ~= LP.Team
end

local function w2s(pos)
    local s, vis = Camera:WorldToViewportPoint(pos)
    return Vector2.new(s.X, s.Y), vis
end

local function getHeadPos(char)
    local h = char:FindFirstChild("Head")
    if h then return h.Position end
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") and v.Name:lower():find("head") then
            return v.Position
        end
    end
    local hrp = getRoot(char)
    return hrp and (hrp.Position + Vector3.new(0,1.6,0)) or nil
end

local function getHeadPart(char)
    local h = char:FindFirstChild("Head")
    if h then return h end
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") and v.Name:lower():find("head") then return v end
    end
    return getRoot(char)
end

local function distFrom(pos)
    local lc  = getChar(LP)
    local lhr = lc and getRoot(lc)
    if not lhr then return math.huge end
    return (lhr.Position - pos).Magnitude
end

-- ════════════════════════════════
--  COLETA DE TARGETS
--  retorna lista de {char, isBot}
-- ════════════════════════════════
local function getAllTargets()
    local targets = {}

    -- players reais
    if CFG.ShowPlayers or CFG.TargetPlayers then
        for _, p in ipairs(Players:GetPlayers()) do
            if p == LP then continue end
            if not isEnemy(p) then continue end
            local c = getChar(p)
            if c and isAlive(c) then
                table.insert(targets, {char=c, bot=false, player=p})
            end
        end
    end

    -- bots: varredura no workspace
    if CFG.ShowBots or CFG.TargetBots then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and isBot(obj) then
                local hum = getHum(obj)
                local hrp = getRoot(obj)
                if hum and hum.Health > 0 and hrp then
                    -- evita duplicar players detectados errado
                    table.insert(targets, {char=obj, bot=true, player=nil})
                end
            end
        end
    end

    return targets
end

-- ════════════════════════════════
--  SILENT AIM
--  hookeia FireServer pra redirecionar
--  o raycast da arma sem mover câmera
-- ════════════════════════════════
local silentTarget = nil   -- part alvo atual

pcall(function()
    local oldIndex = workspace.__index or {}
    -- hook no FindPartOnRay / FindPartOnRayWithIgnoreList / Raycast
    -- método compatível com a maioria dos executors
    local mt2 = getrawmetatable(workspace)
    setreadonly(mt2, false)
    local oldNc = mt2.__namecall
    mt2.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if CFG.SilentAim and silentTarget and silentTarget.Parent then
            if method == "FindPartOnRay" or
               method == "FindPartOnRayWithIgnoreList" or
               method == "FindPartOnRayWithWhitelist" then
                local args = {...}
                local ray  = args[1]
                if ray and typeof(ray) == "Ray" then
                    -- redireciona direção do raio pro head do alvo
                    local dir = (silentTarget.Position - ray.Origin).Unit * ray.Direction.Magnitude
                    args[1]   = Ray.new(ray.Origin, dir)
                    return oldNc(self, table.unpack(args))
                end
            elseif method == "Raycast" then
                local args = {...}
                local orig = args[1]
                local dir  = args[2]
                if orig and dir and typeof(orig)=="Vector3" and typeof(dir)=="Vector3" then
                    local newDir = (silentTarget.Position - orig).Unit * dir.Magnitude
                    args[2]      = newDir
                    return oldNc(self, table.unpack(args))
                end
            end
        end
        return oldNc(self, ...)
    end)
    setreadonly(mt2, true)
end)

-- ════════════════════════════════
--  AIMBOT
-- ════════════════════════════════
local function getBestTarget()
    local best, bestD = nil, CFG.AimbotFOV
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

    for _, t in ipairs(getAllTargets()) do
        if t.bot  and not CFG.TargetBots    then continue end
        if not t.bot and not CFG.TargetPlayers then continue end

        local hpos = getHeadPos(t.char)
        if not hpos then continue end
        local sp, vis = w2s(hpos)
        if not vis then continue end
        local d = (center - sp).Magnitude
        if d < bestD then bestD = d; best = t end
    end
    return best
end

local function getAimPos(t)
    local hpos = getHeadPos(t.char)
    if not hpos then return nil end
    if CFG.Prediction then
        local hrp = getRoot(t.char)
        if hrp then
            local v = hrp.AssemblyLinearVelocity
            hpos = hpos + Vector3.new(v.X,0,v.Z)*CFG.PredictStr
        end
    end
    return hpos
end

-- ════════════════════════════════
--  ESP
-- ════════════════════════════════
-- cores: azul ciano = player, laranja = bot
local COL_PLAYER = Color3.fromRGB(0,  180, 255)
local COL_BOT    = Color3.fromRGB(255, 140,  0)
local WHITE      = Color3.new(1,1,1)
local BLACK      = Color3.new(0,0,0)

local espCache = {}   -- [char] = {draws}

local function newDraw(kind, props)
    local o = Drawing.new(kind)
    for k,v in pairs(props) do o[k]=v end
    return o
end

local function buildESPFor(char, col)
    if espCache[char] then return end
    espCache[char] = {
        col    = col,
        boxSh  = newDraw("Square",{Visible=false,Filled=false,Color=BLACK, Thickness=3,  Transparency=0.65}),
        box    = newDraw("Square",{Visible=false,Filled=false,Color=col,   Thickness=1.5}),
        name   = newDraw("Text",  {Visible=false,Color=WHITE, Size=14,Outline=true,OutlineColor=BLACK,Center=true,Font=2}),
        tag    = newDraw("Text",  {Visible=false,Color=col,   Size=11,Outline=true,OutlineColor=BLACK,Center=true,Font=2}),
        dist   = newDraw("Text",  {Visible=false,Color=col,   Size=11,Outline=true,OutlineColor=BLACK,Center=true,Font=2}),
        hbg    = newDraw("Square",{Visible=false,Filled=true, Color=BLACK, Transparency=0.45}),
        hbar   = newDraw("Square",{Visible=false,Filled=true, Color=col}),
        tracer = newDraw("Line",  {Visible=false,Color=col,   Thickness=1, Transparency=0.5}),
    }
end

local function removeESPFor(char)
    if not espCache[char] then return end
    for _,o in pairs(espCache[char]) do
        if type(o)~="userdata" then continue end
        pcall(function() o:Remove() end)
    end
    espCache[char] = nil
end

local function hideESPFor(char)
    if not espCache[char] then return end
    for k,o in pairs(espCache[char]) do
        if type(o)=="userdata" then o.Visible=false end
    end
end

local function updateESP()
    -- marca todos como "não vistos" neste frame
    local seen = {}

    for _, t in ipairs(getAllTargets()) do
        local char = t.char
        local bot  = t.bot
        if bot  and not CFG.ShowBots    then continue end
        if not bot and not CFG.ShowPlayers then continue end
        if not CFG.ESP then continue end

        local col = bot and COL_BOT or COL_PLAYER
        buildESPFor(char, col)
        seen[char] = true

        local esp = espCache[char]
        esp.col   = col   -- atualiza cor se mudou

        local hrp = getRoot(char)
        if not hrp then hideESPFor(char) continue end

        local hpos = getHeadPos(char)
        if not hpos then hideESPFor(char) continue end

        local topSp, topVis = w2s(hpos + Vector3.new(0,0.5,0))
        local botSp, botVis = w2s(hrp.Position - Vector3.new(0,3,0))
        if not topVis and not botVis then hideESPFor(char) continue end

        local h    = math.abs(botSp.Y - topSp.Y)
        local w    = math.max(h*0.45, 20)
        local left = topSp.X - w/2
        local d    = distFrom(hrp.Position)

        -- box sombra
        esp.boxSh.Visible  = CFG.ESPBoxes
        esp.box.Visible    = CFG.ESPBoxes
        esp.box.Color      = col
        if CFG.ESPBoxes then
            esp.boxSh.Position = Vector2.new(left+1, topSp.Y+1)
            esp.boxSh.Size     = Vector2.new(w, h)
            esp.box.Position   = Vector2.new(left, topSp.Y)
            esp.box.Size       = Vector2.new(w, h)
        end

        -- nome
        esp.name.Visible = CFG.ESPNames
        if CFG.ESPNames then
            local nm = bot and (getHum(char) and char.Name or "Bot") or
                       (t.player and t.player.DisplayName or "?")
            esp.name.Text     = nm
            esp.name.Position = Vector2.new(topSp.X, topSp.Y - 18)
        end

        -- tag BOT/PLAYER
        esp.tag.Visible = true
        esp.tag.Color   = col
        esp.tag.Text    = bot and "[BOT]" or "[PLAYER]"
        esp.tag.Position = Vector2.new(topSp.X, topSp.Y - 30)

        -- distância
        esp.dist.Visible = CFG.ESPDist
        esp.dist.Color   = col
        if CFG.ESPDist then
            esp.dist.Text     = string.format("%.0fm", d)
            esp.dist.Position = Vector2.new(topSp.X, botSp.Y + 4)
        end

        -- health bar
        local hum = getHum(char)
        local pct = hum and math.clamp(hum.Health/hum.MaxHealth,0,1) or 0
        esp.hbg.Visible  = CFG.ESPHealth
        esp.hbar.Visible = CFG.ESPHealth
        if CFG.ESPHealth then
            local bx = left - 7
            esp.hbg.Position  = Vector2.new(bx-1, topSp.Y-1)
            esp.hbg.Size      = Vector2.new(5, h+2)
            esp.hbar.Position = Vector2.new(bx, topSp.Y + h*(1-pct))
            esp.hbar.Size     = Vector2.new(3, h*pct)
            esp.hbar.Color    = Color3.fromHSV(pct*0.33,1,1)
        end

        -- tracer
        esp.tracer.Visible = CFG.ESPTracers
        esp.tracer.Color   = col
        if CFG.ESPTracers then
            local cv = Camera.ViewportSize
            esp.tracer.From = Vector2.new(cv.X/2, cv.Y)
            esp.tracer.To   = Vector2.new(topSp.X, botSp.Y)
        end
    end

    -- limpa chars que sumiram
    for char in pairs(espCache) do
        if not seen[char] then
            hideESPFor(char)
        end
    end
end

-- ════════════════════════════════
--  CROSSHAIR
-- ════════════════════════════════
local chH = newDraw("Line",{Visible=true,Color=WHITE,Thickness=1,Transparency=0.3})
local chV = newDraw("Line",{Visible=true,Color=WHITE,Thickness=1,Transparency=0.3})
local chDot = newDraw("Circle",{Visible=true,Color=COL_PLAYER,Thickness=1,Filled=true,Radius=2})

local function updateCrosshair()
    local vis = CFG.Crosshair
    local cv  = Camera.ViewportSize
    local cx, cy = cv.X/2, cv.Y/2
    local sz = 10
    chH.Visible = vis; chV.Visible = vis; chDot.Visible = vis
    if vis then
        chH.From = Vector2.new(cx-sz, cy); chH.To = Vector2.new(cx+sz, cy)
        chV.From = Vector2.new(cx, cy-sz); chV.To = Vector2.new(cx, cy+sz)
        chDot.Position = Vector2.new(cx, cy)
    end
end

-- ════════════════════════════════
--  GUI
-- ════════════════════════════════
local gui = Instance.new("ScreenGui")
gui.Name           = "SystemkkjHub"
gui.ResetOnSpawn   = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
gui.Parent         = PGui

local C = {
    bg      = Color3.fromRGB(11, 13, 20),
    sidebar = Color3.fromRGB( 7,  9, 15),
    panel   = Color3.fromRGB(15, 18, 27),
    header  = Color3.fromRGB( 9, 11, 18),
    acc     = Color3.fromRGB( 0,185,255),
    acc2    = Color3.fromRGB( 0,120,200),
    botCol  = Color3.fromRGB(255,140,  0),
    text    = Color3.fromRGB(220,232,255),
    dim     = Color3.fromRGB(110,130,170),
    row     = Color3.fromRGB( 20, 24, 36),
    ton     = Color3.fromRGB(  0,185,255),
    toff    = Color3.fromRGB( 32, 38, 58),
    white   = Color3.new(1,1,1),
    black   = Color3.new(0,0,0),
}

local HUB_W    = 580
local HUB_H    = 360
local SB_W     = 140
local minimized = false

-- ── container ────────────────────────────────────────────
local hub = Instance.new("Frame")
hub.Name             = "Hub"
hub.Size             = UDim2.new(0,0,0,0)
hub.Position         = UDim2.new(0.5,-HUB_W/2,0.5,-HUB_H/2)
hub.BackgroundColor3 = C.bg
hub.BorderSizePixel  = 0
hub.ClipsDescendants = true
hub.Visible          = false
hub.ZIndex           = 20
hub.Parent           = gui
Instance.new("UICorner",hub).CornerRadius = UDim.new(0,12)
local hubStroke = Instance.new("UIStroke",hub)
hubStroke.Color       = C.acc
hubStroke.Thickness   = 1
hubStroke.Transparency = 0.55

-- ── header ───────────────────────────────────────────────
local header = Instance.new("Frame")
header.Size             = UDim2.new(1,0,0,38)
header.BackgroundColor3 = C.header
header.BorderSizePixel  = 0
header.ZIndex           = 21
header.Parent           = hub

-- linha inferior header
local hl = Instance.new("Frame")
hl.Size             = UDim2.new(1,0,0,1)
hl.Position         = UDim2.new(0,0,1,-1)
hl.BackgroundColor3 = C.acc
hl.BackgroundTransparency = 0.65
hl.BorderSizePixel  = 0
hl.ZIndex           = 22
hl.Parent           = header

-- dot + título
local dot = Instance.new("Frame")
dot.Size             = UDim2.new(0,8,0,8)
dot.Position         = UDim2.new(0,14,0.5,-4)
dot.BackgroundColor3 = C.acc
dot.BorderSizePixel  = 0
dot.ZIndex           = 23
dot.Parent           = header
Instance.new("UICorner",dot).CornerRadius = UDim.new(1,0)

local pulse = Instance.new("Frame")
pulse.Size             = UDim2.new(0,8,0,8)
pulse.Position         = UDim2.new(0,14,0.5,-4)
pulse.BackgroundColor3 = C.acc
pulse.BackgroundTransparency = 0.5
pulse.BorderSizePixel  = 0
pulse.ZIndex           = 22
pulse.Parent           = header
Instance.new("UICorner",pulse).CornerRadius = UDim.new(1,0)

-- pulso animado no dot
task.spawn(function()
    while true do
        TweenService:Create(pulse,TweenInfo.new(0.9,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),
            {Size=UDim2.new(0,20,0,20),Position=UDim2.new(0,8,0.5,-10),BackgroundTransparency=1}):Play()
        task.wait(0.9)
        pulse.Size     = UDim2.new(0,8,0,8)
        pulse.Position = UDim2.new(0,14,0.5,-4)
        pulse.BackgroundTransparency = 0.5
        task.wait(0.4)
    end
end)

local htitle = Instance.new("TextLabel")
htitle.Size               = UDim2.new(0,180,1,0)
htitle.Position           = UDim2.new(0,30,0,0)
htitle.BackgroundTransparency = 1
htitle.Text               = "Systemkkj Hub"
htitle.TextColor3         = C.text
htitle.TextSize           = 14
htitle.Font               = Enum.Font.GothamBold
htitle.TextXAlignment     = Enum.TextXAlignment.Left
htitle.ZIndex             = 23
htitle.Parent             = header

local hver = Instance.new("TextLabel")
hver.Size               = UDim2.new(0,40,1,0)
hver.Position           = UDim2.new(0,185,0,0)
hver.BackgroundTransparency = 1
hver.Text               = "v3.0"
hver.TextColor3         = C.dim
hver.TextSize           = 11
hver.Font               = Enum.Font.Gotham
hver.TextXAlignment     = Enum.TextXAlignment.Left
hver.ZIndex             = 23
hver.Parent             = header

local function mkHBtn(icon, x, col)
    local b = Instance.new("TextButton")
    b.Size             = UDim2.new(0,26,0,26)
    b.Position         = UDim2.new(1,x,0.5,-13)
    b.BackgroundColor3 = C.row
    b.Text             = icon
    b.TextColor3       = col or C.dim
    b.TextSize         = 13
    b.Font             = Enum.Font.GothamBold
    b.BorderSizePixel  = 0
    b.ZIndex           = 24
    b.Parent           = header
    Instance.new("UICorner",b).CornerRadius = UDim.new(0,6)
    return b
end
local closeBtn = mkHBtn("✕",  -10, Color3.fromRGB(255,70,70))
local miniBtn  = mkHBtn("─",  -40, C.dim)

-- ── sidebar ──────────────────────────────────────────────
local sidebar = Instance.new("Frame")
sidebar.Size             = UDim2.new(0,SB_W,1,-38)
sidebar.Position         = UDim2.new(0,0,0,38)
sidebar.BackgroundColor3 = C.sidebar
sidebar.BorderSizePixel  = 0
sidebar.ZIndex           = 21
sidebar.Parent           = hub

local sdiv = Instance.new("Frame")
sdiv.Size             = UDim2.new(0,1,1,0)
sdiv.Position         = UDim2.new(1,-1,0,0)
sdiv.BackgroundColor3 = C.acc
sdiv.BackgroundTransparency = 0.8
sdiv.BorderSizePixel  = 0
sdiv.ZIndex           = 22
sdiv.Parent           = sidebar

-- badge usuário
local badge = Instance.new("Frame")
badge.Size             = UDim2.new(1,-16,0,60)
badge.Position         = UDim2.new(0,8,0,10)
badge.BackgroundColor3 = C.row
badge.BorderSizePixel  = 0
badge.ZIndex           = 22
badge.Parent           = sidebar
Instance.new("UICorner",badge).CornerRadius = UDim.new(0,8)
local bStroke = Instance.new("UIStroke",badge)
bStroke.Color       = C.acc
bStroke.Thickness   = 1
bStroke.Transparency = 0.7

local bIcon = Instance.new("TextLabel")
bIcon.Size               = UDim2.new(1,0,0,30)
bIcon.Position           = UDim2.new(0,0,0,6)
bIcon.BackgroundTransparency = 1
bIcon.Text               = "⚡"
bIcon.TextSize           = 22
bIcon.Font               = Enum.Font.GothamBold
bIcon.TextColor3         = C.acc
bIcon.ZIndex             = 23
bIcon.Parent             = badge

local bName = Instance.new("TextLabel")
bName.Size               = UDim2.new(1,-8,0,16)
bName.Position           = UDim2.new(0,4,1,-20)
bName.BackgroundTransparency = 1
bName.Text               = LP.Name
bName.TextSize           = 10
bName.Font               = Enum.Font.Gotham
bName.TextColor3         = C.dim
bName.TextXAlignment     = Enum.TextXAlignment.Center
bName.TextTruncate       = Enum.TextTruncate.AtEnd
bName.ZIndex             = 23
bName.Parent             = badge

-- abas
local tabs      = {}
local tabFrames = {}
local activeTab = nil

local tabDefs = {
    {icon="🎯", label="Aimbot"},
    {icon="👁",  label="ESP"},
    {icon="🔇",  label="Silent"},
    {icon="🛡",  label="Misc"},
}

local tabList = Instance.new("Frame")
tabList.Size               = UDim2.new(1,-16,0,0)
tabList.Position           = UDim2.new(0,8,0,80)
tabList.BackgroundTransparency = 1
tabList.ZIndex             = 22
tabList.Parent             = sidebar
local tabLL = Instance.new("UIListLayout",tabList)
tabLL.Padding   = UDim.new(0,4)
tabLL.SortOrder = Enum.SortOrder.LayoutOrder
tabLL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    tabList.Size = UDim2.new(1,-16,0,tabLL.AbsoluteContentSize.Y)
end)

local function setTab(name)
    activeTab = name
    for n,b in pairs(tabs) do
        local on = n==name
        TweenService:Create(b,TweenInfo.new(0.15),{
            BackgroundColor3      = on and C.acc2 or C.sidebar,
            BackgroundTransparency= on and 0.25 or 1,
            TextColor3            = on and C.white or C.dim,
        }):Play()
    end
    for n,f in pairs(tabFrames) do f.Visible = n==name end
end

for i,def in ipairs(tabDefs) do
    local b = Instance.new("TextButton")
    b.Size               = UDim2.new(1,0,0,34)
    b.BackgroundColor3   = C.sidebar
    b.BackgroundTransparency = 1
    b.Text               = def.icon.."  "..def.label
    b.TextColor3         = C.dim
    b.TextSize           = 12
    b.Font               = Enum.Font.GothamBold
    b.TextXAlignment     = Enum.TextXAlignment.Left
    b.BorderSizePixel    = 0
    b.LayoutOrder        = i
    b.ZIndex             = 23
    b.Parent             = tabList
    Instance.new("UICorner",b).CornerRadius = UDim.new(0,7)
    local pd = Instance.new("UIPadding",b); pd.PaddingLeft = UDim.new(0,10)
    tabs[def.label] = b
    b.MouseButton1Click:Connect(function() setTab(def.label) end)
end

-- legenda de cores no fim da sidebar
local legend = Instance.new("Frame")
legend.Size               = UDim2.new(1,-16,0,46)
legend.Position           = UDim2.new(0,8,1,-54)
legend.BackgroundColor3   = C.row
legend.BorderSizePixel    = 0
legend.ZIndex             = 22
legend.Parent             = sidebar
Instance.new("UICorner",legend).CornerRadius = UDim.new(0,7)

local function mkLegendRow(icon, label, col, posY)
    local dot2 = Instance.new("Frame")
    dot2.Size             = UDim2.new(0,8,0,8)
    dot2.Position         = UDim2.new(0,8,0,posY+2)
    dot2.BackgroundColor3 = col
    dot2.BorderSizePixel  = 0
    dot2.ZIndex           = 23
    dot2.Parent           = legend
    Instance.new("UICorner",dot2).CornerRadius = UDim.new(1,0)
    local lt = Instance.new("TextLabel")
    lt.Size               = UDim2.new(1,-20,0,14)
    lt.Position           = UDim2.new(0,20,0,posY)
    lt.BackgroundTransparency = 1
    lt.Text               = label
    lt.TextColor3         = col
    lt.TextSize           = 10
    lt.Font               = Enum.Font.Gotham
    lt.TextXAlignment     = Enum.TextXAlignment.Left
    lt.ZIndex             = 23
    lt.Parent             = legend
end
mkLegendRow("●","Player",COL_PLAYER,  6)
mkLegendRow("●","Bot",   COL_BOT,    24)

-- ── painel direito ───────────────────────────────────────
local panel = Instance.new("Frame")
panel.Size             = UDim2.new(1,-SB_W,1,-38)
panel.Position         = UDim2.new(0,SB_W,0,38)
panel.BackgroundColor3 = C.panel
panel.BorderSizePixel  = 0
panel.ZIndex           = 21
panel.Parent           = hub

local scroll = Instance.new("ScrollingFrame")
scroll.Size                 = UDim2.new(1,-16,1,-16)
scroll.Position             = UDim2.new(0,8,0,8)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness   = 3
scroll.ScrollBarImageColor3 = C.acc
scroll.CanvasSize           = UDim2.new(0,0,0,0)
scroll.ZIndex               = 22
scroll.Parent               = panel

-- ── factories ────────────────────────────────────────────
local function mkSection(parent, text, order)
    local f = Instance.new("Frame")
    f.Size               = UDim2.new(1,0,0,26)
    f.BackgroundTransparency = 1
    f.LayoutOrder        = order
    f.ZIndex             = 23
    f.Parent             = parent
    local line = Instance.new("Frame")
    line.Size             = UDim2.new(1,-12,0,1)
    line.Position         = UDim2.new(0,6,0.5,0)
    line.BackgroundColor3 = C.acc
    line.BackgroundTransparency = 0.72
    line.BorderSizePixel  = 0
    line.ZIndex           = 24
    line.Parent           = f
    local bg2 = Instance.new("Frame")
    bg2.BackgroundColor3 = C.panel
    bg2.BorderSizePixel  = 0
    bg2.ZIndex           = 25
    bg2.Parent           = f
    local lt = Instance.new("TextLabel")
    lt.BackgroundTransparency = 1
    lt.Text               = text
    lt.TextColor3         = C.acc
    lt.TextSize           = 11
    lt.Font               = Enum.Font.GothamBold
    lt.ZIndex             = 26
    lt.Parent             = bg2
    task.defer(function()
        local tw = lt.TextBounds.X+14
        bg2.Size     = UDim2.new(0,tw,1,0)
        bg2.Position = UDim2.new(0,6,0,0)
        lt.Size      = UDim2.new(1,0,1,0)
        lt.Position  = UDim2.new(0,6,0,0)
    end)
end

local function mkToggle(parent, label, cfgKey, order)
    local state = CFG[cfgKey]
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1,0,0,38)
    row.BackgroundColor3 = C.row
    row.BackgroundTransparency = 0.55
    row.BorderSizePixel  = 0
    row.LayoutOrder      = order
    row.ZIndex           = 23
    row.Parent           = parent
    Instance.new("UICorner",row).CornerRadius = UDim.new(0,8)

    local ind = Instance.new("Frame")
    ind.Size             = UDim2.new(0,3,0,22)
    ind.Position         = UDim2.new(0,0,0.5,-11)
    ind.BackgroundColor3 = C.acc
    ind.BackgroundTransparency = state and 0 or 1
    ind.BorderSizePixel  = 0
    ind.ZIndex           = 24
    ind.Parent           = row
    Instance.new("UICorner",ind).CornerRadius = UDim.new(1,0)

    local lbl = Instance.new("TextLabel")
    lbl.Size               = UDim2.new(1,-70,1,0)
    lbl.Position           = UDim2.new(0,14,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Text               = label
    lbl.TextColor3         = state and C.text or C.dim
    lbl.TextSize           = 13
    lbl.Font               = Enum.Font.Gotham
    lbl.TextXAlignment     = Enum.TextXAlignment.Left
    lbl.ZIndex             = 24
    lbl.Parent             = row

    local pill = Instance.new("Frame")
    pill.Size             = UDim2.new(0,42,0,22)
    pill.Position         = UDim2.new(1,-52,0.5,-11)
    pill.BackgroundColor3 = state and C.ton or C.toff
    pill.BorderSizePixel  = 0
    pill.ZIndex           = 24
    pill.Parent           = row
    Instance.new("UICorner",pill).CornerRadius = UDim.new(1,0)

    local knob = Instance.new("Frame")
    knob.Size             = UDim2.new(0,16,0,16)
    knob.Position         = state and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)
    knob.BackgroundColor3 = C.white
    knob.BorderSizePixel  = 0
    knob.ZIndex           = 25
    knob.Parent           = pill
    Instance.new("UICorner",knob).CornerRadius = UDim.new(1,0)

    local hit = Instance.new("TextButton")
    hit.Size               = UDim2.new(1,0,1,0)
    hit.BackgroundTransparency = 1
    hit.Text               = ""
    hit.ZIndex             = 26
    hit.Parent             = row

    hit.MouseButton1Click:Connect(function()
        state       = not state
        CFG[cfgKey] = state
        TweenService:Create(pill, TweenInfo.new(0.15),{BackgroundColor3=state and C.ton or C.toff}):Play()
        TweenService:Create(knob, TweenInfo.new(0.15),{Position=state and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)}):Play()
        TweenService:Create(ind,  TweenInfo.new(0.15),{BackgroundTransparency=state and 0 or 1}):Play()
        lbl.TextColor3 = state and C.text or C.dim
    end)
end

local function mkSlider(parent, label, cfgKey, minV, maxV, order, fmt)
    fmt = fmt or "%.0f"
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1,0,0,48)
    row.BackgroundColor3 = C.row
    row.BackgroundTransparency = 0.55
    row.BorderSizePixel  = 0
    row.LayoutOrder      = order
    row.ZIndex           = 23
    row.Parent           = parent
    Instance.new("UICorner",row).CornerRadius = UDim.new(0,8)

    local lbl = Instance.new("TextLabel")
    lbl.Size               = UDim2.new(0.65,0,0,22)
    lbl.Position           = UDim2.new(0,14,0,4)
    lbl.BackgroundTransparency = 1
    lbl.Text               = label
    lbl.TextColor3         = C.text
    lbl.TextSize           = 13
    lbl.Font               = Enum.Font.Gotham
    lbl.TextXAlignment     = Enum.TextXAlignment.Left
    lbl.ZIndex             = 24
    lbl.Parent             = row

    local valL = Instance.new("TextLabel")
    valL.Size               = UDim2.new(0.35,-14,0,22)
    valL.Position           = UDim2.new(0.65,0,0,4)
    valL.BackgroundTransparency = 1
    valL.Text               = string.format(fmt, CFG[cfgKey])
    valL.TextColor3         = C.acc
    valL.TextSize           = 12
    valL.Font               = Enum.Font.GothamBold
    valL.TextXAlignment     = Enum.TextXAlignment.Right
    valL.ZIndex             = 24
    valL.Parent             = row

    local track = Instance.new("Frame")
    track.Size             = UDim2.new(1,-28,0,4)
    track.Position         = UDim2.new(0,14,1,-14)
    track.BackgroundColor3 = C.toff
    track.BorderSizePixel  = 0
    track.ZIndex           = 24
    track.Parent           = row
    Instance.new("UICorner",track).CornerRadius = UDim.new(1,0)

    local pct0 = (CFG[cfgKey]-minV)/(maxV-minV)
    local fill = Instance.new("Frame")
    fill.Size             = UDim2.new(pct0,0,1,0)
    fill.BackgroundColor3 = C.acc
    fill.BorderSizePixel  = 0
    fill.ZIndex           = 25
    fill.Parent           = track
    Instance.new("UICorner",fill).CornerRadius = UDim.new(1,0)

    local thumb = Instance.new("Frame")
    thumb.Size             = UDim2.new(0,10,0,10)
    thumb.AnchorPoint      = Vector2.new(0.5,0.5)
    thumb.Position         = UDim2.new(pct0,0,0.5,0)
    thumb.BackgroundColor3 = C.white
    thumb.BorderSizePixel  = 0
    thumb.ZIndex           = 26
    thumb.Parent           = track
    Instance.new("UICorner",thumb).CornerRadius = UDim.new(1,0)

    local dragging = false
    local hit2 = Instance.new("TextButton")
    hit2.Size               = UDim2.new(1,0,0,20)
    hit2.Position           = UDim2.new(0,0,1,-20)
    hit2.BackgroundTransparency = 1
    hit2.Text               = ""
    hit2.ZIndex             = 27
    hit2.Parent             = row

    local function upd(mx)
        local abs = track.AbsolutePosition
        local wid = track.AbsoluteSize.X
        local p   = math.clamp((mx-abs.X)/wid,0,1)
        local val
        if fmt == "%.2f" then
            val = math.floor((minV+p*(maxV-minV))*100+0.5)/100
        else
            val = math.floor(minV+p*(maxV-minV))
        end
        CFG[cfgKey]     = val
        fill.Size       = UDim2.new(p,0,1,0)
        thumb.Position  = UDim2.new(p,0,0.5,0)
        valL.Text       = string.format(fmt,val)
    end

    hit2.MouseButton1Down:Connect(function() dragging=true end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
            upd(i.Position.X)
        end
    end)
end

-- ── conteúdo por aba ─────────────────────────────────────
local function buildTab(name)
    local c = Instance.new("Frame")
    c.Size               = UDim2.new(1,0,0,0)
    c.BackgroundTransparency = 1
    c.ZIndex             = 22
    c.Visible            = false
    c.Parent             = scroll
    tabFrames[name]      = c
    local ll = Instance.new("UIListLayout",c)
    ll.SortOrder = Enum.SortOrder.LayoutOrder
    ll.Padding   = UDim.new(0,5)
    ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        c.Size = UDim2.new(1,0,0,ll.AbsoluteContentSize.Y)
        scroll.CanvasSize = UDim2.new(0,0,0,ll.AbsoluteContentSize.Y+10)
    end)
    return c
end

-- ABA AIMBOT
local at = buildTab("Aimbot")
mkSection(at,"AIMBOT",          1)
mkToggle(at,"Aimbot  [Q]",      "Aimbot",        2)
mkToggle(at,"Prediction",       "Prediction",    3)
mkSection(at,"TARGETS",         4)
mkToggle(at,"Mirar Players",    "TargetPlayers", 5)
mkToggle(at,"Mirar Bots",       "TargetBots",    6)
mkSection(at,"AJUSTE",          7)
mkSlider(at,"FOV",              "AimbotFOV",    50,500,8)
mkSlider(at,"Smooth",           "AimbotSmooth",0.05,0.5,9,"%.2f")

-- ABA ESP
local et = buildTab("ESP")
mkSection(et,"VISIBILIDADE",    1)
mkToggle(et,"ESP",              "ESP",           2)
mkToggle(et,"Boxes",            "ESPBoxes",      3)
mkToggle(et,"Nomes",            "ESPNames",      4)
mkToggle(et,"Distância",        "ESPDist",       5)
mkToggle(et,"Health Bar",       "ESPHealth",     6)
mkToggle(et,"Tracers",          "ESPTracers",    7)
mkSection(et,"FILTROS",         8)
mkToggle(et,"Mostrar Players",  "ShowPlayers",   9)
mkToggle(et,"Mostrar Bots",     "ShowBots",      10)

-- ABA SILENT
local st = buildTab("Silent")
mkSection(st,"SILENT AIM",      1)
mkToggle(st,"Silent Aim",       "SilentAim",     2)
mkSection(st,"CROSSHAIR",       3)
mkToggle(st,"Crosshair",        "Crosshair",     4)

-- ABA MISC
local mt2 = buildTab("Misc")
mkSection(mt2,"PROTEÇÃO",       1)
mkToggle(mt2,"Anti-Kick",       "AntiKick",      2)
mkSection(mt2,"FILTROS",        3)
mkToggle(mt2,"Team Check",      "TeamCheck",     4)

setTab("Aimbot")

-- ── drag ─────────────────────────────────────────────────
local dh,ds,sp2 = false,nil,nil
header.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then dh=true;ds=i.Position;sp2=hub.Position end
end)
UserInputService.InputChanged:Connect(function(i)
    if dh and i.UserInputType==Enum.UserInputType.MouseMovement then
        local d=i.Position-ds
        hub.Position=UDim2.new(sp2.X.Scale,sp2.X.Offset+d.X,sp2.Y.Scale,sp2.Y.Offset+d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then dh=false end
end)

-- ── abrir / fechar / mini ────────────────────────────────
local function openHub()
    minimized=false; miniBtn.Text="─"
    hub.Visible=true; hub.Size=UDim2.new(0,0,0,0)
    TweenService:Create(hub,TweenInfo.new(0.35,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
        {Size=UDim2.new(0,HUB_W,0,HUB_H)}):Play()
end
local function closeHub()
    TweenService:Create(hub,TweenInfo.new(0.25,Enum.EasingStyle.Back,Enum.EasingDirection.In),
        {Size=UDim2.new(0,0,0,0)}):Play()
    task.wait(0.3); hub.Visible=false
end
local function toggleMini()
    minimized=not minimized
    TweenService:Create(hub,TweenInfo.new(0.2,Enum.EasingStyle.Quad),
        {Size=UDim2.new(0,HUB_W,0,minimized and 38 or HUB_H)}):Play()
    miniBtn.Text = minimized and "□" or "─"
end

closeBtn.MouseButton1Click:Connect(closeHub)
miniBtn.MouseButton1Click:Connect(toggleMini)
UserInputService.InputBegan:Connect(function(i,gpe)
    if gpe then return end
    if i.KeyCode==Enum.KeyCode.Insert then
        if hub.Visible then closeHub() else openHub() end
    end
end)

-- ── intro ────────────────────────────────────────────────
local intro = Instance.new("Frame")
intro.Size                  = UDim2.new(1,0,1,0)
intro.BackgroundColor3      = Color3.fromRGB(6,8,14)
intro.BackgroundTransparency = 0
intro.BorderSizePixel       = 0
intro.ZIndex                = 100
intro.Parent                = gui

local gc = Instance.new("Frame")
gc.Size                  = UDim2.new(0,420,0,195)
gc.Position              = UDim2.new(0.5,-210,0.5,-97)
gc.BackgroundColor3      = Color3.fromRGB(0,185,255)
gc.BackgroundTransparency = 1
gc.BorderSizePixel       = 0
gc.ZIndex                = 102
gc.Parent                = intro
Instance.new("UICorner",gc).CornerRadius = UDim.new(0,16)
local gcSt = Instance.new("UIStroke",gc)
gcSt.Color=Color3.fromRGB(0,185,255);gcSt.Thickness=1.2;gcSt.Transparency=0.4

local ilt = Instance.new("TextLabel")
ilt.Size               = UDim2.new(1,0,0,48)
ilt.Position           = UDim2.new(0,0,0,30)
ilt.BackgroundTransparency = 1
ilt.Text               = "Systemkkj Hub"
ilt.TextColor3         = Color3.fromRGB(220,240,255)
ilt.TextSize           = 30
ilt.Font               = Enum.Font.GothamBold
ilt.TextTransparency   = 1
ilt.ZIndex             = 104
ilt.Parent             = gc

local isub2 = Instance.new("TextLabel")
isub2.Size               = UDim2.new(1,0,0,20)
isub2.Position           = UDim2.new(0,0,0,82)
isub2.BackgroundTransparency = 1
isub2.Text               = "Sniper Arena  •  v3.0  •  Inicializando..."
isub2.TextColor3         = Color3.fromRGB(0,185,255)
isub2.TextSize           = 12
isub2.Font               = Enum.Font.Gotham
isub2.TextTransparency   = 1
isub2.ZIndex             = 104
isub2.Parent             = gc

local lbg2 = Instance.new("Frame")
lbg2.Size             = UDim2.new(0,340,0,4)
lbg2.Position         = UDim2.new(0.5,-170,0,130)
lbg2.BackgroundColor3 = Color3.fromRGB(18,28,46)
lbg2.BorderSizePixel  = 0
lbg2.ZIndex           = 104
lbg2.Parent           = gc
Instance.new("UICorner",lbg2).CornerRadius = UDim.new(1,0)

local lf2 = Instance.new("Frame")
lf2.Size             = UDim2.new(0,0,1,0)
lf2.BackgroundColor3 = Color3.fromRGB(0,185,255)
lf2.BorderSizePixel  = 0
lf2.ZIndex           = 105
lf2.Parent           = lbg2
Instance.new("UICorner",lf2).CornerRadius = UDim.new(1,0)

task.spawn(function()
    TweenService:Create(gc,  TweenInfo.new(0.4),{BackgroundTransparency=0.82}):Play()
    task.wait(0.3)
    TweenService:Create(ilt, TweenInfo.new(0.5),{TextTransparency=0}):Play()
    task.wait(0.3)
    TweenService:Create(isub2,TweenInfo.new(0.4),{TextTransparency=0}):Play()
    task.wait(0.2)
    TweenService:Create(lf2, TweenInfo.new(1.5,Enum.EasingStyle.Quad),{Size=UDim2.new(1,0,1,0)}):Play()
    task.wait(1.7)
    for _,o in ipairs({intro,gc,lbg2,lf2}) do
        TweenService:Create(o,TweenInfo.new(0.3),{BackgroundTransparency=1}):Play()
    end
    TweenService:Create(ilt,  TweenInfo.new(0.3),{TextTransparency=1}):Play()
    TweenService:Create(isub2,TweenInfo.new(0.3),{TextTransparency=1}):Play()
    TweenService:Create(gcSt, TweenInfo.new(0.3),{Transparency=1}):Play()
    task.wait(0.35); intro.Visible=false
    openHub()
end)

-- ════════════════════════════════
--  LOOP PRINCIPAL
-- ════════════════════════════════
RunService.RenderStepped:Connect(function()
    updateESP()
    updateCrosshair()

    -- atualiza silent target todo frame
    silentTarget = nil
    if CFG.SilentAim or CFG.Aimbot then
        local best = getBestTarget()
        if best then
            silentTarget = getHeadPart(best.char)
        end
    end

    -- aimbot normal (move câmera)
    if CFG.Aimbot and not CFG.SilentAim and
       UserInputService:IsKeyDown(CFG.AimbotKey) then
        local best = getBestTarget()
        if best then
            local pos = getAimPos(best)
            if pos then
                local _,vis = w2s(pos)
                if vis then
                    Camera.CFrame = Camera.CFrame:Lerp(
                        CFrame.new(Camera.CFrame.Position, pos),
                        CFG.AimbotSmooth
                    )
                end
            end
        end
    end
end)

print("[Systemkkj Hub v3] ON — INSERT abre/fecha | ─ minimiza | Q = aimbot")