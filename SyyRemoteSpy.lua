--[[
    SYY Remote Spy — Versión móvil ligera
    • NO usa hookmetamethod global (eso explota el celular)
    • Hookea solo FireServer / InvokeServer en cada remote individual
    • Cooldown por remote para no spamear el log
    • UI simple con scroll, filtro por nombre, botón limpiar
    • Auto-detecta nuevos remotes que se añadan al juego
]]

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local pGui      = player:WaitForChild("PlayerGui")

-- ── Eliminar instancia anterior ─────────────────────────────
local oldGui = pGui:FindFirstChild("SyySpyUI")
if oldGui then oldGui:Destroy() end

-- ── CONFIG ──────────────────────────────────────────────────
local MAX_LOG     = 120   -- máximo de entradas en el log (evita memory leak)
local COOLDOWN    = 0.25  -- segundos mínimos entre logs del MISMO remote
local isMobile    = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ── GUI ──────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "SyySpyUI"; gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true; gui.DisplayOrder = 100
gui.Parent = pGui

local C_BG     = Color3.fromRGB(6,10,18)
local C_ROW    = Color3.fromRGB(8,14,28)
local C_ACCENT = Color3.fromRGB(0,190,255)
local C_TEXT   = Color3.fromRGB(180,240,255)
local C_DIM    = Color3.fromRGB(70,160,210)
local C_GREEN  = Color3.fromRGB(80,255,140)
local C_YELLOW = Color3.fromRGB(255,215,0)

local vp      = workspace.CurrentCamera.ViewportSize
local panelW  = isMobile and math.min(math.floor(vp.X*0.96), 420) or 480
local panelH  = isMobile and math.min(math.floor(vp.Y*0.80), 560) or 500

local main = Instance.new("Frame")
main.Name       = "SpyPanel"
main.Size       = UDim2.fromOffset(panelW, panelH)
main.Position   = UDim2.new(0.5, -panelW/2, 0.5, -panelH/2)
main.BackgroundColor3 = C_BG
main.BorderSizePixel  = 0
main.ClipsDescendants = true
main.Parent     = gui

local function stroke(p,col,th)
    local s=Instance.new("UIStroke"); s.Color=col or C_ACCENT
    s.Thickness=th or 1; s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; s.Parent=p; return s
end
stroke(main, C_ACCENT, 2)

-- Header
local hdrH = isMobile and 46 or 36
local hdr  = Instance.new("Frame")
hdr.Size   = UDim2.new(1,0,0,hdrH)
hdr.BackgroundColor3 = Color3.fromRGB(3,7,14)
hdr.BorderSizePixel  = 0; hdr.Parent = main

local title = Instance.new("TextLabel")
title.Size  = UDim2.new(1,-140,1,0); title.Position = UDim2.fromOffset(10,0)
title.BackgroundTransparency = 1; title.Text = "🔍 SYY Remote Spy"
title.TextColor3 = C_ACCENT; title.Font = Enum.Font.GothamBlack
title.TextSize = isMobile and 16 or 14
title.TextXAlignment = Enum.TextXAlignment.Left; title.Parent = hdr

local countLbl = Instance.new("TextLabel")
countLbl.Size  = UDim2.fromOffset(60, hdrH)
countLbl.Position = UDim2.new(1,-130,0,0)
countLbl.BackgroundTransparency = 1; countLbl.Text = "0 logs"
countLbl.TextColor3 = C_DIM; countLbl.Font = Enum.Font.GothamMedium
countLbl.TextSize = isMobile and 11 or 9
countLbl.Parent = hdr

local clrBtn = Instance.new("TextButton")
clrBtn.Size  = UDim2.fromOffset(isMobile and 58 or 48, isMobile and 30 or 24)
clrBtn.Position = UDim2.new(1,-130,0.5,-(isMobile and 15 or 12))
clrBtn.BackgroundColor3 = Color3.fromRGB(0,30,50)
clrBtn.BorderSizePixel = 0; clrBtn.Text = "🗑 Clear"
clrBtn.TextColor3 = C_ACCENT; clrBtn.Font = Enum.Font.GothamBold
clrBtn.TextSize = isMobile and 10 or 9; clrBtn.AutoButtonColor = false
clrBtn.Parent = hdr; stroke(clrBtn,C_ACCENT,1)

local xBtn = Instance.new("TextButton")
local xSz  = isMobile and 38 or 30
xBtn.Size  = UDim2.fromOffset(xSz,xSz)
xBtn.Position = UDim2.new(1,-(xSz+4),0.5,-xSz/2)
xBtn.BackgroundColor3 = Color3.fromRGB(35,8,8)
xBtn.BorderSizePixel = 0; xBtn.Text = "✕"
xBtn.TextColor3 = Color3.fromRGB(255,80,80)
xBtn.Font = Enum.Font.GothamBold; xBtn.TextSize = isMobile and 15 or 12
xBtn.AutoButtonColor = false; xBtn.Parent = hdr
stroke(xBtn,Color3.fromRGB(120,30,30),1)
xBtn.MouseButton1Click:Connect(function() main.Visible = false end)

-- Filtro
local filterH = isMobile and 34 or 26
local filterRow = Instance.new("Frame")
filterRow.Size = UDim2.new(1,0,0,filterH)
filterRow.Position = UDim2.fromOffset(0,hdrH)
filterRow.BackgroundColor3 = Color3.fromRGB(4,9,18)
filterRow.BorderSizePixel = 0; filterRow.Parent = main

local filterBox = Instance.new("TextBox")
filterBox.Size = UDim2.new(1,-10,1,-6)
filterBox.Position = UDim2.fromOffset(5,3)
filterBox.BackgroundColor3 = Color3.fromRGB(3,7,14)
filterBox.BorderSizePixel = 0
filterBox.Text = ""; filterBox.PlaceholderText = "🔎 Filtrar por nombre de remote..."
filterBox.PlaceholderColor3 = C_DIM; filterBox.TextColor3 = C_TEXT
filterBox.Font = Enum.Font.GothamMedium; filterBox.TextSize = isMobile and 12 or 10
filterBox.ClearTextOnFocus = false; filterBox.Parent = filterRow
stroke(filterBox,Color3.fromRGB(0,60,90),1)

-- Scroll log
local scrollY = hdrH + filterH + 2
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1,-2,0, panelH-scrollY-4)
scroll.Position = UDim2.fromOffset(1,scrollY)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = isMobile and 5 or 3
scroll.ScrollBarImageColor3 = C_ACCENT
scroll.CanvasSize = UDim2.new(0,0,0,0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = main

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0,1)
listLayout.Parent = scroll

-- ── DRAG ────────────────────────────────────────────────────
do
    local drag,ds,sp2=false,nil,nil
    local dh=Instance.new("TextButton")
    dh.Size=UDim2.new(1,-140,0,hdrH); dh.BackgroundTransparency=1
    dh.Text=""; dh.ZIndex=5; dh.Parent=main
    dh.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            drag=true; ds=inp.Position; sp2=main.Position end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then drag=false end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if drag and (inp.UserInputType==Enum.UserInputType.MouseMovement
        or inp.UserInputType==Enum.UserInputType.Touch) then
            local d=inp.Position-ds
            main.Position=UDim2.new(sp2.X.Scale,sp2.X.Offset+d.X,sp2.Y.Scale,sp2.Y.Offset+d.Y)
        end
    end)
end

-- ── LOG ENTRIES ──────────────────────────────────────────────
local logEntries = {}   -- {frame, text, color, visible}
local filterText = ""
local logCount   = 0

local ROW_H = isMobile and 52 or 42

local function serializeArg(v)
    local t = typeof(v)
    if t == "Vector3"   then return ("V3(%.1f,%.1f,%.1f)"):format(v.X,v.Y,v.Z) end
    if t == "CFrame"    then return ("CF(%.1f,%.1f,%.1f)"):format(v.X,v.Y,v.Z) end
    if t == "Instance"  then return "Inst:"..v:GetFullName() end
    if t == "boolean"   then return tostring(v) end
    if t == "number"    then return ("%.3g"):format(v) end
    if t == "string"    then return '"'..(#v>40 and v:sub(1,40).."…" or v)..'"' end
    if t == "table"     then return "{table #"..#v.."}" end
    return t.."("..tostring(v)..")"
end

local function addLog(remoteName, remotePath, method, args)
    logCount = logCount + 1

    -- Construir string de args (máximo 4 args para no explotar el teléfono)
    local argParts = {}
    for i=1, math.min(#args, 4) do
        argParts[i] = serializeArg(args[i])
    end
    if #args > 4 then argParts[#argParts+1] = "…+"..( #args-4).." más" end
    local argStr = table.concat(argParts, "  │  ")

    local col = method=="FireServer" and C_GREEN or C_YELLOW
    local shortPath = remotePath
    -- Acortar path largo
    local parts = {}
    for p in remotePath:gmatch("[^%.]+") do parts[#parts+1]=p end
    if #parts > 4 then
        shortPath = "…/"..table.concat(parts,"/",#parts-3)
    end

    -- Frame UI
    local e = Instance.new("Frame")
    e.Size = UDim2.new(1,0,0,ROW_H)
    e.BackgroundColor3 = C_ROW
    e.BorderSizePixel = 0
    e.LayoutOrder = logCount

    -- método tag
    local tag = Instance.new("TextLabel")
    tag.Size = UDim2.fromOffset(isMobile and 68 or 60, isMobile and 18 or 14)
    tag.Position = UDim2.fromOffset(4,3)
    tag.BackgroundColor3 = method=="FireServer"
        and Color3.fromRGB(0,50,20) or Color3.fromRGB(50,40,0)
    tag.BorderSizePixel = 0
    tag.Text = method=="FireServer" and "FireServer" or "InvokeServer"
    tag.TextColor3 = col; tag.Font = Enum.Font.GothamBold
    tag.TextSize = isMobile and 9 or 8; tag.Parent = e
    stroke(tag, col, 1)

    -- nombre remote
    local namLbl = Instance.new("TextLabel")
    namLbl.Size = UDim2.new(1,-16, 0, isMobile and 18 or 14)
    namLbl.Position = UDim2.fromOffset(isMobile and 76 or 68, 3)
    namLbl.BackgroundTransparency = 1
    namLbl.Text = remoteName
    namLbl.TextColor3 = C_TEXT; namLbl.Font = Enum.Font.GothamBold
    namLbl.TextSize = isMobile and 12 or 10
    namLbl.TextXAlignment = Enum.TextXAlignment.Left; namLbl.Parent = e

    -- path completo
    local pathLbl = Instance.new("TextLabel")
    pathLbl.Size = UDim2.new(1,-8, 0, isMobile and 14 or 12)
    pathLbl.Position = UDim2.fromOffset(4, isMobile and 22 or 18)
    pathLbl.BackgroundTransparency = 1
    pathLbl.Text = shortPath
    pathLbl.TextColor3 = C_DIM; pathLbl.Font = Enum.Font.GothamMedium
    pathLbl.TextSize = isMobile and 9 or 8
    pathLbl.TextXAlignment = Enum.TextXAlignment.Left; pathLbl.Parent = e

    -- args
    local argsLbl = Instance.new("TextLabel")
    argsLbl.Size = UDim2.new(1,-8, 0, isMobile and 14 or 12)
    argsLbl.Position = UDim2.fromOffset(4, isMobile and 36 or 29)
    argsLbl.BackgroundTransparency = 1
    argsLbl.Text = argStr=="" and "(sin args)" or argStr
    argsLbl.TextColor3 = C_ACCENT; argsLbl.Font = Enum.Font.GothamMedium
    argsLbl.TextSize = isMobile and 9 or 8
    argsLbl.TextXAlignment = Enum.TextXAlignment.Left; argsLbl.Parent = e

    -- botón copiar path
    local cpSz = isMobile and 22 or 18
    local cpBtn = Instance.new("TextButton")
    cpBtn.Size = UDim2.fromOffset(cpSz,cpSz)
    cpBtn.Position = UDim2.new(1,-(cpSz+3),0,3)
    cpBtn.BackgroundColor3 = Color3.fromRGB(0,20,40)
    cpBtn.BorderSizePixel = 0; cpBtn.Text = "📋"
    cpBtn.Font = Enum.Font.GothamBold; cpBtn.TextSize = isMobile and 9 or 8
    cpBtn.AutoButtonColor = false; cpBtn.Parent = e
    stroke(cpBtn,Color3.fromRGB(0,60,90),1)
    local copied = false
    cpBtn.MouseButton1Click:Connect(function()
        if copied then return end; copied = true
        pcall(function() setclipboard(remotePath) end)
        cpBtn.Text = "✅"
        task.delay(1.5, function() cpBtn.Text = "📋"; copied = false end)
    end)

    -- Aplicar filtro
    local fLow = filterText:lower()
    e.Visible = fLow=="" or remoteName:lower():find(fLow,1,true)~=nil
    e.Parent = scroll

    -- Guardar en lista
    table.insert(logEntries, {frame=e, name=remoteName})

    -- Recortar si hay demasiadas entradas
    if #logEntries > MAX_LOG then
        local old = table.remove(logEntries,1)
        if old.frame and old.frame.Parent then old.frame:Destroy() end
    end

    -- Actualizar contador
    countLbl.Text = #logEntries.." logs"

    -- Auto-scroll al fondo
    task.defer(function()
        scroll.CanvasPosition = Vector2.new(0, math.huge)
    end)
end

-- ── FILTRO EN TIEMPO REAL ────────────────────────────────────
filterBox:GetPropertyChangedSignal("Text"):Connect(function()
    filterText = filterBox.Text or ""
    local fLow = filterText:lower()
    for _, entry in ipairs(logEntries) do
        if entry.frame and entry.frame.Parent then
            entry.frame.Visible = fLow=="" or entry.name:lower():find(fLow,1,true)~=nil
        end
    end
end)

clrBtn.MouseButton1Click:Connect(function()
    for _, entry in ipairs(logEntries) do
        if entry.frame and entry.frame.Parent then entry.frame:Destroy() end
    end
    logEntries = {}; logCount = 0; countLbl.Text = "0 logs"
end)

-- ── HOOKING INDIVIDUAL POR REMOTE ───────────────────────────
-- En vez de hookear __namecall global (explosivo en móvil),
-- reemplazamos FireServer / InvokeServer de cada remote uno a uno.
-- Mucho más barato: solo corre cuando el juego llama ESE remote.

local hookedRemotes = {}  -- [remote] = true
local lastLog       = {}  -- [remote] = tick() para cooldown

local function hookRemote(remote)
    if hookedRemotes[remote] then return end
    hookedRemotes[remote] = true

    local path   = remote:GetFullName()
    local name   = remote.Name
    local isFunc = remote:IsA("RemoteFunction")

    if not isFunc then
        -- RemoteEvent → hookear FireServer
        local orig = remote.FireServer
        remote.FireServer = newcclosure(function(self, ...)
            local now = tick()
            if (now - (lastLog[remote] or 0)) >= COOLDOWN then
                lastLog[remote] = now
                local args = {...}
                task.defer(function() addLog(name, path, "FireServer", args) end)
            end
            return orig(self, ...)
        end)
    else
        -- RemoteFunction → hookear InvokeServer
        local orig = remote.InvokeServer
        remote.InvokeServer = newcclosure(function(self, ...)
            local now = tick()
            if (now - (lastLog[remote] or 0)) >= COOLDOWN then
                lastLog[remote] = now
                local args = {...}
                task.defer(function() addLog(name, path, "InvokeServer", args) end)
            end
            return orig(self, ...)
        end)
    end
end

-- Hookear todos los remotes existentes y los que se añadan
local function scanAndHook(root)
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            pcall(hookRemote, obj)
        end
    end
end

scanAndHook(game)

-- Detectar nuevos remotes que el juego cree después
game.DescendantAdded:Connect(function(obj)
    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
        task.defer(function() pcall(hookRemote, obj) end)
    end
end)

-- ── FAB para reabrir ─────────────────────────────────────────
local fabSz = isMobile and 56 or 44
local fab = Instance.new("TextButton")
fab.Size = UDim2.fromOffset(fabSz,fabSz)
fab.Position = UDim2.new(0,12,0.5,-(fabSz/2))
fab.BackgroundColor3 = Color3.fromRGB(3,7,14)
fab.BorderSizePixel = 0; fab.Text = "🔍"
fab.Font = Enum.Font.GothamBlack; fab.TextSize = isMobile and 22 or 18
fab.AutoButtonColor = false; fab.ZIndex = 20; fab.Parent = gui
stroke(fab,C_ACCENT,2)
fab.MouseButton1Click:Connect(function()
    main.Visible = not main.Visible
end)

local hookedCount = 0
for _ in pairs(hookedRemotes) do hookedCount = hookedCount + 1 end
print("[SYY Spy] Remote Spy cargado - hooks activos en "..hookedCount.." remotes")