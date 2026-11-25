local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local LocalPlayer      = Players.LocalPlayer

local Library = {}

local function tween(obj, props, t, style, dir)
    if not obj or not obj.Parent then return end
    local info = TweenInfo.new(
        t or 0.18,
        style or Enum.EasingStyle.Quad,
        dir or Enum.EasingDirection.Out
    )
    TweenService:Create(obj, info, props):Play()
end

local function newInst(cls, props, parent)
    local i = Instance.new(cls)
    for k, v in pairs(props) do
        i[k] = v
    end
    i.Parent = parent
    return i
end

local C = {
    GlassPanel  = Color3.fromHex("#0c0e18"),
    GlassCard   = Color3.fromHex("#141828"),
    GlassPopup  = Color3.fromHex("#0e111f"),
    Border      = Color3.fromHex("#323852"),
    TextPri     = Color3.fromHex("#f4f6ff"),
    TextSec     = Color3.fromHex("#9aa2c2"),
    TextMut     = Color3.fromHex("#646b88"),
    Success     = Color3.fromHex("#4fffb0"),
    Danger      = Color3.fromHex("#ff4f7b"),
    Warn        = Color3.fromHex("#ffb84f"),
}

local PALETTES = {
    ESP = {
        "#ff4f7b", "#4fffb0", "#7c6fff", "#ffb84f", "#4fc3ff",
        "#ffffff", "#a855f7", "#38bdf8", "#fb7185", "#a3e635",
    },
    Accent = {
        "#7c6fff", "#ff6f9c", "#4fffb0", "#ffb84f", "#4fc3ff",
        "#ff4f7b", "#a855f7", "#38bdf8", "#fb7185", "#a3e635",
    },
}

function Library:CreateWindow(opts)
    opts = opts or {}
    local titleText     = opts.Title or "Glass Panel"
    local subText       = opts.Subtitle or "glass ui · drag edge to resize"
    local rootName      = opts.Name or "GlassPanel_Lib"
    local startTime     = os.clock()
    local accentColor   = opts.AccentColor or Color3.fromHex("#7c6fff")
    local playerName    = opts.PlayerName or LocalPlayer.DisplayName
    local playerId      = tostring(opts.PlayerID or LocalPlayer.UserId)
    local showProfile   = (opts.ShowProfile ~= false)
    local showStats     = (opts.ShowStats ~= false)
    local footerText    = opts.FooterText or "INSERT → toggle · DELETE → panic"
    local onCloseCb     = opts.OnClose
    local onPanicCb     = opts.OnPanic

    local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
    local existing  = parentGui:FindFirstChild(rootName)
    if existing then existing:Destroy() end

    local GUI = Instance.new("ScreenGui")
    GUI.Name           = rootName
    GUI.ResetOnSpawn   = false
    GUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    GUI.IgnoreGuiInset = true
    GUI.DisplayOrder   = 999
    GUI.Parent         = parentGui

    local state = {
        Visible   = true,
        Minimized = false,
        ActiveTab = nil,
    }

    local accentCallbacks = {}
    local function bindAccent(fn)
        table.insert(accentCallbacks, fn)
        fn(accentColor)
    end

    local function setAccentColor(c3)
        accentColor = c3
        for _, fn in ipairs(accentCallbacks) do
            fn(c3)
        end
    end

    local OverlayLayer = newInst("Frame", {
        Name                   = "OverlayLayer",
        Size                   = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ZIndex                 = 50,
    }, GUI)

    local activeDropdownClose = nil
    local function closeActiveDropdown()
        if activeDropdownClose then
            activeDropdownClose()
            activeDropdownClose = nil
        end
    end

    local ToastHolder = newInst("Frame", {
        Name                   = "ToastHolder",
        Size                   = UDim2.new(0, 210, 1, 0),
        Position               = UDim2.new(1, -220, 0, 0),
        BackgroundTransparency = 1,
        ZIndex                 = 60,
    }, GUI)
    newInst("UIListLayout", {
        FillDirection     = Enum.FillDirection.Vertical,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        Padding           = UDim.new(0, 5),
        SortOrder         = Enum.SortOrder.LayoutOrder,
    }, ToastHolder)
    newInst("UIPadding", {
        PaddingBottom = UDim.new(0, 14),
    }, ToastHolder)

    local function notify(msg, color)
        color = color or accentColor
        local t = newInst("Frame", {
            Name                   = "Toast",
            Size                   = UDim2.new(1, 0, 0, 28),
            BackgroundColor3       = C.GlassPopup,
            BorderSizePixel        = 0,
            BackgroundTransparency = 1,
        }, ToastHolder)
        newInst("UICorner", { CornerRadius = UDim.new(0, 6) }, t)
        newInst("UIStroke", {
            Color           = color,
            Thickness       = 1,
            Transparency    = 0.55,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, t)
        local dot = newInst("Frame", {
            Name             = "Dot",
            Size             = UDim2.new(0, 6, 0, 6),
            Position         = UDim2.new(0, 9, 0.5, -3),
            BackgroundColor3 = color,
            BorderSizePixel  = 0,
        }, t)
        newInst("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
        newInst("TextLabel", {
            Name                   = "Msg",
            Size                   = UDim2.new(1, -24, 1, 0),
            Position               = UDim2.new(0, 22, 0, 0),
            BackgroundTransparency = 1,
            Text                   = msg,
            TextColor3             = C.TextPri,
            TextSize               = 10,
            Font                   = Enum.Font.Code,
            TextXAlignment         = Enum.TextXAlignment.Left,
            TextTruncate           = Enum.TextTruncate.AtEnd,
        }, t)
        tween(t, { BackgroundTransparency = 0.16 }, 0.18)
        task.delay(2, function()
            if t and t.Parent then
                tween(t, { BackgroundTransparency = 1 }, 0.2)
                task.wait(0.22)
                if t then t:Destroy() end
            end
        end)
    end

    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(800, 450)

    local MIN_W, MIN_H = 300, 210
    local MAX_W = math.max(MIN_W, vp.X - 24)
    local MAX_H = math.max(MIN_H, vp.Y - 24)

    local defaultW = opts.Width or 360
    local defaultH = opts.Height or 265

    local currentW = math.clamp(defaultW, MIN_W, MAX_W)
    local currentH = math.clamp(defaultH, MIN_H, MAX_H)

    local HEADER_H  = 38
    local PROFILE_H = showProfile and 48 or 0
    local TAB_H     = 32
    local FOOTER_H  = 30
    local CHROME_H  = HEADER_H + PROFILE_H + TAB_H + FOOTER_H

    local Panel = newInst("Frame", {
        Name                   = "Panel",
        AnchorPoint            = Vector2.new(0, 0),
        Size                   = UDim2.new(0, currentW, 0, 0),
        Position               = UDim2.new(0, math.floor((vp.X - currentW) * 0.5), 0, math.floor((vp.Y - currentH) * 0.5)),
        BackgroundColor3       = C.GlassPanel,
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        ClipsDescendants       = true,
    }, GUI)
    newInst("UICorner", { CornerRadius = UDim.new(0, 12) }, Panel)

    local PanelGlassGrad = newInst("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromHex("#181d30")),
            ColorSequenceKeypoint.new(0.55, Color3.fromHex("#0c0f1a")),
            ColorSequenceKeypoint.new(1, accentColor:Lerp(Color3.fromHex("#090b12"), 0.88)),
        }),
        Rotation = 145,
    }, Panel)

    local PanelStroke = newInst("UIStroke", {
        Color           = accentColor,
        Thickness       = 1.2,
        Transparency    = 0.42,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, Panel)

    bindAccent(function(c3)
        PanelStroke.Color = c3
        PanelGlassGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromHex("#181d30")),
            ColorSequenceKeypoint.new(0.55, Color3.fromHex("#0c0f1a")),
            ColorSequenceKeypoint.new(1, c3:Lerp(Color3.fromHex("#090b12"), 0.86)),
        })
    end)

    local MainContainer = newInst("Frame", {
        Name                   = "MainContainer",
        Size                   = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ZIndex                 = 1,
    }, Panel)

    local Header = newInst("Frame", {
        Name                   = "Header",
        Size                   = UDim2.new(1, 0, 0, HEADER_H),
        Position               = UDim2.new(0, 0, 0, 0),
        BackgroundColor3       = Color3.fromHex("#ffffff"),
        BackgroundTransparency = 0.94,
        BorderSizePixel        = 0,
    }, MainContainer)
    newInst("UIStroke", {
        Color           = C.Border,
        Thickness       = 1,
        Transparency    = 0.4,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, Header)

    local ProfileBar = newInst("Frame", {
        Name                   = "ProfileBar",
        Size                   = UDim2.new(1, 0, 0, PROFILE_H),
        Position               = UDim2.new(0, 0, 0, HEADER_H),
        BackgroundColor3       = C.GlassCard,
        BackgroundTransparency = 0.52,
        BorderSizePixel        = 0,
        Visible                = showProfile,
    }, MainContainer)
    if showProfile then
        newInst("UIStroke", {
            Color           = C.Border,
            Thickness       = 1,
            Transparency    = 0.45,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, ProfileBar)
    end

    local TabBar = newInst("Frame", {
        Name                   = "TabBar",
        Size                   = UDim2.new(1, 0, 0, TAB_H),
        Position               = UDim2.new(0, 0, 0, HEADER_H + PROFILE_H),
        BackgroundColor3       = C.GlassPanel,
        BackgroundTransparency = 0.45,
        BorderSizePixel        = 0,
    }, MainContainer)
    newInst("UIStroke", {
        Color           = C.Border,
        Thickness       = 1,
        Transparency    = 0.45,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, TabBar)
    newInst("UIListLayout", {
        FillDirection       = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment   = Enum.VerticalAlignment.Center,
        Padding             = UDim.new(0, 4),
        SortOrder           = Enum.SortOrder.LayoutOrder,
    }, TabBar)
    newInst("UIPadding", {
        PaddingLeft  = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
    }, TabBar)

    local ContentHolder = newInst("Frame", {
        Name                   = "ContentHolder",
        Size                   = UDim2.new(1, 0, 0, math.max(currentH - CHROME_H, 40)),
        Position               = UDim2.new(0, 0, 0, HEADER_H + PROFILE_H + TAB_H),
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        ClipsDescendants       = true,
    }, MainContainer)

    local Footer = newInst("Frame", {
        Name                   = "Footer",
        Size                   = UDim2.new(1, 0, 0, FOOTER_H),
        Position               = UDim2.new(0, 0, 1, -FOOTER_H),
        BackgroundColor3       = Color3.fromHex("#ffffff"),
        BackgroundTransparency = 0.96,
        BorderSizePixel        = 0,
    }, MainContainer)
    newInst("UIStroke", {
        Color           = C.Border,
        Thickness       = 1,
        Transparency    = 0.45,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, Footer)

    local ResizeLayer = newInst("Frame", {
        Name                   = "ResizeLayer",
        Size                   = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ZIndex                 = 25,
    }, Panel)

    local MinBtn = nil

    local function syncContentHeight(h)
        ContentHolder.Size = UDim2.new(1, 0, 0, math.max(h - CHROME_H, 40))
    end

    local function setMinimized(minimized)
        closeActiveDropdown()
        state.Minimized = minimized
        if MinBtn then
            MinBtn.Text = minimized and "+" or "—"
        end

        if minimized then
            ResizeLayer.Visible = false
            ProfileBar.Visible = false
            TabBar.Visible = false
            ContentHolder.Visible = false
            Footer.Visible = false
            tween(Panel, { Size = UDim2.new(0, currentW, 0, HEADER_H) }, 0.2)
        else
            ProfileBar.Visible = showProfile
            TabBar.Visible = true
            ContentHolder.Visible = true
            Footer.Visible = true
            syncContentHeight(currentH)
            tween(Panel, { Size = UDim2.new(0, currentW, 0, currentH) }, 0.22)
            task.delay(0.22, function()
                if not state.Minimized and state.Visible then
                    ResizeLayer.Visible = true
                end
            end)
        end
    end

    local function setVisible(vis)
        closeActiveDropdown()
        state.Visible = vis
        if vis then
            local targetH = state.Minimized and HEADER_H or currentH
            Panel.Visible = true
            tween(Panel, { Size = UDim2.new(0, currentW, 0, targetH), BackgroundTransparency = 0.22 }, 0.25,
                Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            task.delay(0.25, function()
                if state.Visible and not state.Minimized then
                    ResizeLayer.Visible = true
                end
            end)
        else
            ResizeLayer.Visible = false
            tween(Panel, { Size = UDim2.new(0, currentW, 0, 0), BackgroundTransparency = 1 }, 0.2,
                Enum.EasingStyle.Back, Enum.EasingDirection.In)
            task.delay(0.22, function()
                if not state.Visible then Panel.Visible = false end
            end)
        end
    end

    task.spawn(function()
        task.wait(0.05)
        tween(Panel, { BackgroundTransparency = 0.22, Size = UDim2.new(0, currentW, 0, currentH) }, 0.32,
            Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    end)

    local function enableDrag(dragHandle, targetFrame)
        local dragging = false
        local dragInput = nil
        local dragStart = nil
        local startPos = nil

        dragHandle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                closeActiveDropdown()
                dragging = true
                dragInput = input
                dragStart = input.Position
                startPos = targetFrame.Position
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input == dragInput or input.UserInputType == Enum.UserInputType.MouseMovement) then
                local delta = input.Position - dragStart
                targetFrame.Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
                dragInput = nil
            end
        end)
    end

    enableDrag(Header, Panel)

    local EDGE_THICK = 10
    local CORNER_SZ  = 16

    local function createResizeHandle(name, size, pos, anchor, dirX, dirY, isCorner)
        local handle = newInst("TextButton", {
            Name                   = name,
            AnchorPoint            = anchor,
            Size                   = size,
            Position               = pos,
            BackgroundColor3       = accentColor,
            BackgroundTransparency = 1,
            BorderSizePixel        = 0,
            Text                   = "",
            AutoButtonColor        = false,
            ZIndex                 = isCorner and 27 or 26,
        }, ResizeLayer)

        if isCorner then
            newInst("UICorner", { CornerRadius = UDim.new(0, 4) }, handle)
        end

        local indicator = newInst("Frame", {
            AnchorPoint            = Vector2.new(0.5, 0.5),
            Size                   = isCorner and UDim2.new(0, 6, 0, 6)
                or (dirX ~= 0 and UDim2.new(0, 2, 0.45, 0) or UDim2.new(0.45, 0, 0, 2)),
            Position               = UDim2.new(0.5, 0, 0.5, 0),
            BackgroundColor3       = accentColor,
            BackgroundTransparency = isCorner and 0.5 or 0.82,
            BorderSizePixel        = 0,
            ZIndex                 = 28,
        }, handle)
        newInst("UICorner", { CornerRadius = UDim.new(1, 0) }, indicator)

        bindAccent(function(c3)
            handle.BackgroundColor3 = c3
            indicator.BackgroundColor3 = c3
        end)

        local resizing = false
        local activeInput = nil
        local startMouse = nil
        local startPos = nil
        local startSize = nil

        handle.InputBegan:Connect(function(input)
            if state.Minimized then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                closeActiveDropdown()
                resizing = true
                activeInput = input
                startMouse = input.Position
                startPos = Vector2.new(Panel.Position.X.Offset, Panel.Position.Y.Offset)
                startSize = Vector2.new(Panel.AbsoluteSize.X, Panel.AbsoluteSize.Y)
                tween(indicator, { BackgroundTransparency = 0.1 }, 0.1)
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if resizing and (input == activeInput or input.UserInputType == Enum.UserInputType.MouseMovement) then
                local screen = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 450)
                local maxW = math.max(MIN_W, screen.X - 16)
                local maxH = math.max(MIN_H, screen.Y - 16)

                local delta = input.Position - startMouse
                local newW = startSize.X
                local newH = startSize.Y
                local newX = startPos.X
                local newY = startPos.Y

                if dirX == 1 then
                    newW = math.clamp(startSize.X + delta.X, MIN_W, maxW)
                elseif dirX == -1 then
                    local clampedW = math.clamp(startSize.X - delta.X, MIN_W, maxW)
                    newX = startPos.X + (startSize.X - clampedW)
                    newW = clampedW
                end

                if dirY == 1 then
                    newH = math.clamp(startSize.Y + delta.Y, MIN_H, maxH)
                elseif dirY == -1 then
                    local clampedH = math.clamp(startSize.Y - delta.Y, MIN_H, maxH)
                    newY = startPos.Y + (startSize.Y - clampedH)
                    newH = clampedH
                end

                currentW = math.round(newW)
                currentH = math.round(newH)
                Panel.Position = UDim2.new(0, math.round(newX), 0, math.round(newY))
                Panel.Size = UDim2.new(0, currentW, 0, currentH)
                syncContentHeight(currentH)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if resizing and (input == activeInput or input.UserInputType == Enum.UserInputType.MouseButton1) then
                resizing = false
                activeInput = nil
                tween(indicator, { BackgroundTransparency = isCorner and 0.5 or 0.82 }, 0.15)
            end
        end)
    end

    createResizeHandle("ResizeLeft",   UDim2.new(0, EDGE_THICK, 1, -CORNER_SZ * 2), UDim2.new(0, 0, 0.5, 0), Vector2.new(0, 0.5), -1,  0, false)
    createResizeHandle("ResizeRight",  UDim2.new(0, EDGE_THICK, 1, -CORNER_SZ * 2), UDim2.new(1, 0, 0.5, 0), Vector2.new(1, 0.5),  1,  0, false)
    createResizeHandle("ResizeTop",    UDim2.new(1, -CORNER_SZ * 2, 0, EDGE_THICK), UDim2.new(0.5, 0, 0, 0), Vector2.new(0.5, 0),  0, -1, false)
    createResizeHandle("ResizeBottom", UDim2.new(1, -CORNER_SZ * 2, 0, EDGE_THICK), UDim2.new(0.5, 0, 1, 0), Vector2.new(0.5, 1),  0,  1, false)

    createResizeHandle("ResizeTL", UDim2.new(0, CORNER_SZ, 0, CORNER_SZ), UDim2.new(0, 0, 0, 0), Vector2.new(0, 0), -1, -1, true)
    createResizeHandle("ResizeTR", UDim2.new(0, CORNER_SZ, 0, CORNER_SZ), UDim2.new(1, 0, 0, 0), Vector2.new(1, 0),  1, -1, true)
    createResizeHandle("ResizeBL", UDim2.new(0, CORNER_SZ, 0, CORNER_SZ), UDim2.new(0, 0, 1, 0), Vector2.new(0, 1), -1,  1, true)
    createResizeHandle("ResizeBR", UDim2.new(0, CORNER_SZ, 0, CORNER_SZ), UDim2.new(1, 0, 1, 0), Vector2.new(1, 1),  1,  1, true)

    local Logo = newInst("Frame", {
        Size             = UDim2.new(0, 24, 0, 24),
        Position         = UDim2.new(0, 12, 0.5, -12),
        BackgroundColor3 = accentColor,
        BorderSizePixel  = 0,
    }, Header)
    newInst("UICorner", { CornerRadius = UDim.new(0, 6) }, Logo)
    local LogoGrad = newInst("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, accentColor),
            ColorSequenceKeypoint.new(1, Color3.fromHex("#ff6f9c")),
        }),
        Rotation = 135,
    }, Logo)
    bindAccent(function(c3)
        Logo.BackgroundColor3 = c3
        LogoGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, c3),
            ColorSequenceKeypoint.new(1, c3:Lerp(Color3.new(1, 1, 1), 0.35)),
        })
    end)

    newInst("TextLabel", {
        Size                   = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text                   = opts.Icon or "★",
        TextColor3             = Color3.new(1, 1, 1),
        TextSize               = 12,
        Font                   = Enum.Font.GothamBold,
    }, Logo)

    newInst("TextLabel", {
        Name                   = "Title",
        Size                   = UDim2.new(1, -148, 0, 14),
        Position               = UDim2.new(0, 42, 0, 5),
        BackgroundTransparency = 1,
        Text                   = titleText,
        TextColor3             = C.TextPri,
        TextSize               = 12,
        Font                   = Enum.Font.GothamSemibold,
        TextXAlignment         = Enum.TextXAlignment.Left,
        TextTruncate           = Enum.TextTruncate.AtEnd,
    }, Header)

    newInst("TextLabel", {
        Name                   = "Sub",
        Size                   = UDim2.new(1, -148, 0, 10),
        Position               = UDim2.new(0, 42, 0, 21),
        BackgroundTransparency = 1,
        Text                   = subText,
        TextColor3             = C.TextMut,
        TextSize               = 9,
        Font                   = Enum.Font.Code,
        TextXAlignment         = Enum.TextXAlignment.Left,
        TextTruncate           = Enum.TextTruncate.AtEnd,
    }, Header)

    local StatusDot = newInst("Frame", {
        Size             = UDim2.new(0, 5, 0, 5),
        Position         = UDim2.new(1, -90, 0.5, -2.5),
        BackgroundColor3 = C.Success,
        BorderSizePixel  = 0,
    }, Header)
    newInst("UICorner", { CornerRadius = UDim.new(1, 0) }, StatusDot)

    newInst("TextLabel", {
        Size                   = UDim2.new(0, 30, 1, 0),
        Position               = UDim2.new(1, -82, 0, 0),
        BackgroundTransparency = 1,
        Text                   = opts.Badge or "SAFE",
        TextColor3             = C.Success,
        TextSize               = 9,
        Font                   = Enum.Font.Code,
        TextXAlignment         = Enum.TextXAlignment.Left,
    }, Header)

    task.spawn(function()
        while Panel.Parent do
            tween(StatusDot, { BackgroundTransparency = 0.5 }, 1, Enum.EasingStyle.Sine)
            task.wait(1)
            tween(StatusDot, { BackgroundTransparency = 0 }, 1, Enum.EasingStyle.Sine)
            task.wait(1)
        end
    end)

    MinBtn = newInst("TextButton", {
        Size                   = UDim2.new(0, 20, 0, 20),
        Position               = UDim2.new(1, -52, 0.5, -10),
        BackgroundColor3       = Color3.fromHex("#ffffff"),
        BackgroundTransparency = 0.9,
        BorderSizePixel        = 0,
        Text                   = "—",
        TextColor3             = C.TextPri,
        TextSize               = 10,
        Font                   = Enum.Font.GothamBold,
        ZIndex                 = 30,
    }, Header)
    newInst("UICorner", { CornerRadius = UDim.new(1, 0) }, MinBtn)
    MinBtn.MouseButton1Click:Connect(function()
        setMinimized(not state.Minimized)
    end)

    local CloseBtn = newInst("TextButton", {
        Size                   = UDim2.new(0, 20, 0, 20),
        Position               = UDim2.new(1, -28, 0.5, -10),
        BackgroundColor3       = C.Danger,
        BackgroundTransparency = 0.84,
        BorderSizePixel        = 0,
        Text                   = "✕",
        TextColor3             = C.Danger,
        TextSize               = 10,
        Font                   = Enum.Font.GothamSemibold,
        ZIndex                 = 30,
    }, Header)
    newInst("UICorner", { CornerRadius = UDim.new(1, 0) }, CloseBtn)
    CloseBtn.MouseButton1Click:Connect(function()
        setVisible(false)
        if onCloseCb then onCloseCb() end
    end)

    local AvatarLetter, AvatarImage, ProfileName, ProfileID

    if showProfile then
        local Avatar = newInst("Frame", {
            Size             = UDim2.new(0, 32, 0, 32),
            Position         = UDim2.new(0, 12, 0.5, -16),
            BackgroundColor3 = accentColor,
            BorderSizePixel  = 0,
            ClipsDescendants = true,
        }, ProfileBar)
        newInst("UICorner", { CornerRadius = UDim.new(1, 0) }, Avatar)
        local AvatarStroke = newInst("UIStroke", {
            Color           = accentColor,
            Thickness       = 1.2,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, Avatar)
        local AvatarGrad = newInst("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, accentColor),
                ColorSequenceKeypoint.new(1, Color3.fromHex("#ff6f9c")),
            }),
            Rotation = 135,
        }, Avatar)
        bindAccent(function(c3)
            Avatar.BackgroundColor3 = c3
            AvatarStroke.Color = c3
            AvatarGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, c3),
                ColorSequenceKeypoint.new(1, c3:Lerp(Color3.new(1, 1, 1), 0.35)),
            })
        end)

        AvatarLetter = newInst("TextLabel", {
            Size                   = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text                   = string.upper(string.sub(playerName, 1, 1)),
            TextColor3             = Color3.new(1, 1, 1),
            TextSize               = 14,
            Font                   = Enum.Font.GothamBold,
            ZIndex                 = 1,
        }, Avatar)

        AvatarImage = newInst("ImageLabel", {
            Size                   = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Image                  = "",
            ZIndex                 = 2,
        }, Avatar)
        newInst("UICorner", { CornerRadius = UDim.new(1, 0) }, AvatarImage)

        local function loadAvatarThumbnail(userIdStr)
            local uid = tonumber(userIdStr)
            if not uid then
                AvatarImage.Image = ""
                return
            end
            task.spawn(function()
                local ok, content, isReady = pcall(function()
                    return Players:GetUserThumbnailAsync(
                        uid,
                        Enum.ThumbnailType.HeadShot,
                        Enum.ThumbnailSize.Size100x100
                    )
                end)
                if ok and isReady and content then
                    AvatarImage.Image = content
                else
                    AvatarImage.Image = ""
                end
            end)
        end

        loadAvatarThumbnail(playerId)

        ProfileName = newInst("TextLabel", {
            Name                   = "ProfileName",
            Size                   = UDim2.new(1, showStats and -195 or -64, 0, 14),
            Position               = UDim2.new(0, 52, 0, 9),
            BackgroundTransparency = 1,
            Text                   = playerName,
            TextColor3             = C.TextPri,
            TextSize               = 12,
            Font                   = Enum.Font.GothamSemibold,
            TextXAlignment         = Enum.TextXAlignment.Left,
            TextTruncate           = Enum.TextTruncate.AtEnd,
        }, ProfileBar)

        ProfileID = newInst("TextLabel", {
            Name                   = "ProfileID",
            Size                   = UDim2.new(1, showStats and -195 or -64, 0, 11),
            Position               = UDim2.new(0, 52, 0, 26),
            BackgroundTransparency = 1,
            Text                   = "ID: " .. playerId,
            TextColor3             = C.TextMut,
            TextSize               = 9,
            Font                   = Enum.Font.Code,
            TextXAlignment         = Enum.TextXAlignment.Left,
            TextTruncate           = Enum.TextTruncate.AtEnd,
        }, ProfileBar)

        if showStats then
            local function makeStat(label, xOffset)
                local val = newInst("TextLabel", {
                    Name                   = label .. "Val",
                    Size                   = UDim2.new(0, 42, 0, 14),
                    Position               = UDim2.new(1, xOffset, 0, 9),
                    BackgroundTransparency = 1,
                    Text                   = "—",
                    TextColor3             = accentColor,
                    TextSize               = 11,
                    Font                   = Enum.Font.Code,
                    TextXAlignment         = Enum.TextXAlignment.Center,
                }, ProfileBar)
                bindAccent(function(c3)
                    val.TextColor3 = c3
                end)
                newInst("TextLabel", {
                    Size                   = UDim2.new(0, 42, 0, 9),
                    Position               = UDim2.new(1, xOffset, 0, 26),
                    BackgroundTransparency = 1,
                    Text                   = label,
                    TextColor3             = C.TextMut,
                    TextSize               = 8,
                    Font                   = Enum.Font.GothamSemibold,
                    TextXAlignment         = Enum.TextXAlignment.Center,
                }, ProfileBar)
                return val
            end

            local FPSLabel  = makeStat("FPS",  -138)
            local PingLabel = makeStat("PING", -94)
            local TimeLabel = makeStat("TIME", -50)

            local fpsCounter, lastStep = 0, 0
            RunService.RenderStepped:Connect(function(dt)
                fpsCounter += 1
                lastStep += dt
                if lastStep >= 0.5 then
                    FPSLabel.Text = tostring(math.round(fpsCounter / lastStep))
                    fpsCounter, lastStep = 0, 0
                end
            end)

            task.spawn(function()
                while Panel.Parent do
                    local ok, ping = pcall(function()
                        return math.round(LocalPlayer:GetNetworkPing() * 1000)
                    end)
                    PingLabel.Text = (ok and tostring(ping) or "?") .. "ms"
                    task.wait(1)
                end
            end)

            task.spawn(function()
                while Panel.Parent do
                    local elapsed = math.round(os.clock() - startTime)
                    local m = math.floor(elapsed / 60)
                    local s = elapsed % 60
                    TimeLabel.Text = string.format("%02d:%02d", m, s)
                    task.wait(1)
                end
            end)
        end
    end

    local tabOrderCounter = 0
    local TabButtons = {}
    local TabPanes   = {}

    local function selectTab(label)
        local pane = TabPanes[label]
        if not pane then return end
        closeActiveDropdown()
        state.ActiveTab = label
        for name, tb in pairs(TabButtons) do
            local active = (name == label)
            tween(tb.btn, {
                TextColor3             = active and accentColor or C.TextSec,
                BackgroundTransparency = active and 0.82 or 1,
            }, 0.15)
            tween(tb.ind, { BackgroundTransparency = active and 0 or 1 }, 0.15)
        end
        for name, p in pairs(TabPanes) do
            if name == label then
                p.Visible = true
                p.Position = UDim2.new(0, 6, 0, 0)
                tween(p, { Position = UDim2.new(0, 0, 0, 0) }, 0.16, Enum.EasingStyle.Quad)
            else
                p.Visible = false
            end
        end
    end

    newInst("TextLabel", {
        Size                   = UDim2.new(1, -76, 1, 0),
        Position               = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text                   = footerText,
        TextColor3             = C.TextMut,
        TextSize               = 9,
        Font                   = Enum.Font.Code,
        TextXAlignment         = Enum.TextXAlignment.Left,
        TextTruncate           = Enum.TextTruncate.AtEnd,
    }, Footer)

    local PanicBtn = newInst("TextButton", {
        Size                   = UDim2.new(0, 52, 0, 18),
        Position               = UDim2.new(1, -60, 0.5, -9),
        BackgroundColor3       = C.Danger,
        BackgroundTransparency = 0.85,
        BorderSizePixel        = 0,
        Text                   = "PANIC",
        TextColor3             = C.Danger,
        TextSize               = 9,
        Font                   = Enum.Font.Code,
        ZIndex                 = 30,
    }, Footer)
    newInst("UICorner", { CornerRadius = UDim.new(0, 4) }, PanicBtn)
    newInst("UIStroke", {
        Color           = C.Danger,
        Thickness       = 1,
        Transparency    = 0.55,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, PanicBtn)
    PanicBtn.MouseButton1Click:Connect(function()
        notify("PANIC — unloading…", C.Danger)
        if onPanicCb then pcall(onPanicCb) end
        task.delay(0.3, function()
            if GUI then GUI:Destroy() end
        end)
    end)

    local windowApi = {}

    function windowApi:Notify(msg, color)
        notify(msg, color)
    end

    function windowApi:SetAccent(c3)
        setAccentColor(c3)
    end

    function windowApi:GetAccent()
        return accentColor
    end

    function windowApi:SetVisible(vis)
        setVisible(vis)
    end

    function windowApi:IsVisible()
        return state.Visible
    end

    function windowApi:SetMinimized(minimized)
        setMinimized(minimized)
    end

    function windowApi:SetProfile(newName, newId)
        if not showProfile then return end
        if newName and ProfileName and AvatarLetter then
            local display = newName ~= "" and newName or LocalPlayer.DisplayName
            ProfileName.Text = display
            AvatarLetter.Text = string.upper(string.sub(display, 1, 1))
        end
        if newId and ProfileID and AvatarImage then
            local cleanId = newId ~= "" and newId or tostring(LocalPlayer.UserId)
            ProfileID.Text = "ID: " .. cleanId
            local uid = tonumber(cleanId)
            if uid then
                task.spawn(function()
                    local ok, content, isReady = pcall(function()
                        return Players:GetUserThumbnailAsync(
                            uid,
                            Enum.ThumbnailType.HeadShot,
                            Enum.ThumbnailSize.Size100x100
                        )
                    end)
                    AvatarImage.Image = (ok and isReady and content) and content or ""
                end)
            else
                AvatarImage.Image = ""
            end
        end
    end

    function windowApi:Destroy()
        closeActiveDropdown()
        if GUI then GUI:Destroy() end
    end

    function windowApi:CreateTab(label)
        tabOrderCounter += 1
        local order = tabOrderCounter

        local btn = newInst("TextButton", {
            Name                   = "Tab_" .. label,
            Size                   = UDim2.new(0.25, -4, 0, 24),
            BackgroundColor3       = accentColor,
            BackgroundTransparency = 1,
            BorderSizePixel        = 0,
            Text                   = label,
            TextColor3             = C.TextSec,
            TextSize               = 10,
            Font                   = Enum.Font.GothamSemibold,
            LayoutOrder            = order,
        }, TabBar)
        newInst("UICorner", { CornerRadius = UDim.new(0, 5) }, btn)

        local indicator = newInst("Frame", {
            Name                   = "Indicator",
            Size                   = UDim2.new(0.65, 0, 0, 2),
            Position               = UDim2.new(0.175, 0, 1, -2),
            BackgroundColor3       = accentColor,
            BackgroundTransparency = 1,
            BorderSizePixel        = 0,
        }, btn)
        newInst("UICorner", { CornerRadius = UDim.new(1, 0) }, indicator)

        bindAccent(function(c3)
            btn.BackgroundColor3 = c3
            indicator.BackgroundColor3 = c3
            if state.ActiveTab == label then
                btn.TextColor3 = c3
            end
        end)

        TabButtons[label] = { btn = btn, ind = indicator }

        local pane = newInst("ScrollingFrame", {
            Name                 = "Pane_" .. label,
            Size                 = UDim2.new(1, 0, 1, 0),
            Position             = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 1,
            BorderSizePixel      = 0,
            ScrollBarThickness   = 3,
            ScrollBarImageColor3 = accentColor,
            CanvasSize           = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize  = Enum.AutomaticSize.Y,
            Visible              = false,
        }, ContentHolder)
        bindAccent(function(c3)
            pane.ScrollBarImageColor3 = c3
        end)
        pane:GetPropertyChangedSignal("CanvasPosition"):Connect(closeActiveDropdown)

        newInst("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder     = Enum.SortOrder.LayoutOrder,
            Padding       = UDim.new(0, 5),
        }, pane)
        newInst("UIPadding", {
            PaddingTop    = UDim.new(0, 8),
            PaddingLeft   = UDim.new(0, 12),
            PaddingRight  = UDim.new(0, 12),
            PaddingBottom = UDim.new(0, 10),
        }, pane)
        TabPanes[label] = pane

        btn.MouseButton1Click:Connect(function()
            selectTab(label)
        end)

        if not state.ActiveTab then
            selectTab(label)
        end

        local itemOrder = 0
        local function nextOrder()
            itemOrder += 1
            return itemOrder
        end

        local function glassRow(height)
            local r = newInst("Frame", {
                Size                   = UDim2.new(1, 0, 0, height or 32),
                BackgroundColor3       = C.GlassCard,
                BackgroundTransparency = 0.42,
                BorderSizePixel        = 0,
                LayoutOrder            = nextOrder(),
            }, pane)
            newInst("UICorner", { CornerRadius = UDim.new(0, 6) }, r)
            newInst("UIStroke", {
                Color           = C.Border,
                Thickness       = 1,
                Transparency    = 0.65,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            }, r)
            r.MouseEnter:Connect(function() tween(r, { BackgroundTransparency = 0.25 }, 0.12) end)
            r.MouseLeave:Connect(function() tween(r, { BackgroundTransparency = 0.42 }, 0.12) end)
            return r
        end

        local function rowLabel(parent, text, subtext, rightReserve)
            local reserve = rightReserve or 140
            local lbl = newInst("TextLabel", {
                Size                   = UDim2.new(1, -reserve, 0, subtext and 13 or 32),
                Position               = UDim2.new(0, 9, subtext and 0 or 0, subtext and 4 or 0),
                BackgroundTransparency = 1,
                Text                   = text,
                TextColor3             = C.TextPri,
                TextSize               = 11,
                Font                   = Enum.Font.GothamSemibold,
                TextXAlignment         = Enum.TextXAlignment.Left,
                TextTruncate           = Enum.TextTruncate.AtEnd,
            }, parent)
            if subtext then
                newInst("TextLabel", {
                    Size                   = UDim2.new(1, -reserve, 0, 10),
                    Position               = UDim2.new(0, 9, 0, 19),
                    BackgroundTransparency = 1,
                    Text                   = subtext,
                    TextColor3             = C.TextMut,
                    TextSize               = 9,
                    Font                   = Enum.Font.Code,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    TextTruncate           = Enum.TextTruncate.AtEnd,
                }, parent)
            end
            return lbl
        end

        local tabApi = {}

        function tabApi:Select()
            selectTab(label)
        end

        function tabApi:AddSection(text)
            local f = newInst("Frame", {
                Size                   = UDim2.new(1, 0, 0, 18),
                BackgroundTransparency = 1,
                LayoutOrder            = nextOrder(),
            }, pane)
            newInst("TextLabel", {
                Size                   = UDim2.new(1, -4, 1, 0),
                Position               = UDim2.new(0, 2, 0, 0),
                BackgroundTransparency = 1,
                Text                   = string.upper(text),
                TextColor3             = C.TextMut,
                TextSize               = 8,
                Font                   = Enum.Font.GothamSemibold,
                TextXAlignment         = Enum.TextXAlignment.Left,
            }, f)
            newInst("Frame", {
                Size                   = UDim2.new(1, 0, 0, 1),
                Position               = UDim2.new(0, 0, 1, -1),
                BackgroundColor3       = C.Border,
                BackgroundTransparency = 0.35,
                BorderSizePixel        = 0,
            }, f)
            return f
        end

        function tabApi:AddToggle(cfg)
            cfg = cfg or {}
            local text     = cfg.Title or "Toggle"
            local subtext  = cfg.Subtext
            local keytxt   = cfg.Badge
            local val      = (cfg.Default == true)
            local callback = cfg.Callback

            local r = glassRow(subtext and 36 or 32)
            rowLabel(r, text, subtext, keytxt and 95 or 58)

            if keytxt then
                local b = newInst("TextLabel", {
                    AnchorPoint            = Vector2.new(1, 0.5),
                    Size                   = UDim2.new(0, 0, 0, 16),
                    Position               = UDim2.new(1, -48, 0.5, 0),
                    AutomaticSize          = Enum.AutomaticSize.X,
                    BackgroundColor3       = Color3.fromHex("#ffffff"),
                    BackgroundTransparency = 0.92,
                    BorderSizePixel        = 0,
                    Text                   = keytxt,
                    TextColor3             = C.TextMut,
                    TextSize               = 8,
                    Font                   = Enum.Font.Code,
                    TextXAlignment         = Enum.TextXAlignment.Center,
                }, r)
                newInst("UICorner", { CornerRadius = UDim.new(0, 4) }, b)
                newInst("UIStroke", {
                    Color           = C.Border,
                    Thickness       = 1,
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                }, b)
                newInst("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }, b)
            end

            local track = newInst("Frame", {
                Size                   = UDim2.new(0, 32, 0, 18),
                Position               = UDim2.new(1, -40, 0.5, -9),
                BackgroundColor3       = val and accentColor or C.Border,
                BackgroundTransparency = val and 0.65 or 0.45,
                BorderSizePixel        = 0,
            }, r)
            newInst("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
            local trackStroke = newInst("UIStroke", {
                Color           = val and accentColor or C.Border,
                Thickness       = 1,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            }, track)

            local thumb = newInst("Frame", {
                Size             = UDim2.new(0, 12, 0, 12),
                Position         = val and UDim2.new(0, 17, 0.5, -6) or UDim2.new(0, 3, 0.5, -6),
                BackgroundColor3 = val and accentColor or C.TextSec,
                BorderSizePixel  = 0,
            }, track)
            newInst("UICorner", { CornerRadius = UDim.new(1, 0) }, thumb)

            local function refresh(instant)
                local dur = instant and 0 or 0.16
                tween(track, {
                    BackgroundColor3       = val and accentColor or C.Border,
                    BackgroundTransparency = val and 0.65 or 0.45,
                }, dur)
                tween(thumb, {
                    Position         = val and UDim2.new(0, 17, 0.5, -6) or UDim2.new(0, 3, 0.5, -6),
                    BackgroundColor3 = val and accentColor or C.TextSec,
                }, dur)
                trackStroke.Color = val and accentColor or C.Border
            end

            bindAccent(function()
                refresh(true)
            end)

            local function setValue(newVal, silent)
                val = (newVal == true)
                refresh(false)
                if not silent then
                    notify(text .. ": " .. (val and "ON" or "OFF"), val and C.Success or C.Danger)
                end
                if callback then callback(val) end
            end

            local btn = newInst("TextButton", {
                Size                   = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text                   = "",
            }, r)
            btn.MouseButton1Click:Connect(function()
                closeActiveDropdown()
                setValue(not val, false)
            end)

            return {
                Set = function(_, v, silent) setValue(v, silent) end,
                Get = function() return val end,
            }
        end

        function tabApi:AddSlider(cfg)
            cfg = cfg or {}
            local text     = cfg.Title or "Slider"
            local subtext  = cfg.Subtext
            local minVal   = cfg.Min or 0
            local maxVal   = cfg.Max or 100
            local suffix   = cfg.Suffix or ""
            local val      = math.clamp(cfg.Default or minVal, minVal, maxVal)
            local callback = cfg.Callback

            local r = glassRow(subtext and 36 or 32)
            rowLabel(r, text, subtext, 160)

            local valLbl = newInst("TextLabel", {
                Size                   = UDim2.new(0, 38, 1, 0),
                Position               = UDim2.new(1, -44, 0, 0),
                BackgroundTransparency = 1,
                Text                   = tostring(val) .. suffix,
                TextColor3             = accentColor,
                TextSize               = 10,
                Font                   = Enum.Font.Code,
                TextXAlignment         = Enum.TextXAlignment.Right,
            }, r)

            local track = newInst("Frame", {
                Size                   = UDim2.new(0, 102, 0, 4),
                Position               = UDim2.new(1, -150, 0.5, -2),
                BackgroundColor3       = C.Border,
                BackgroundTransparency = 0.35,
                BorderSizePixel        = 0,
            }, r)
            newInst("UICorner", { CornerRadius = UDim.new(1, 0) }, track)

            local denom = math.max(maxVal - minVal, 1)
            local pct0 = (val - minVal) / denom
            local fill = newInst("Frame", {
                Size             = UDim2.new(pct0, 0, 1, 0),
                BackgroundColor3 = accentColor,
                BorderSizePixel  = 0,
            }, track)
            newInst("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)

            local knob = newInst("Frame", {
                Size             = UDim2.new(0, 12, 0, 12),
                Position         = UDim2.new(pct0, -6, 0.5, -6),
                BackgroundColor3 = accentColor,
                BorderSizePixel  = 0,
                ZIndex           = 2,
            }, track)
            newInst("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)

            bindAccent(function(c3)
                valLbl.TextColor3 = c3
                fill.BackgroundColor3 = c3
                knob.BackgroundColor3 = c3
            end)

            local function applyValue(newVal, fireCb)
                val = math.clamp(math.round(newVal), minVal, maxVal)
                local t = (val - minVal) / denom
                valLbl.Text = tostring(val) .. suffix
                tween(fill, { Size = UDim2.new(t, 0, 1, 0) }, 0.04)
                tween(knob, { Position = UDim2.new(t, -6, 0.5, -6) }, 0.04)
                if fireCb and callback then callback(val) end
            end

            local draggingSlider = false
            local function updateFromMouse(x)
                local abs = track.AbsolutePosition.X
                local w   = math.max(track.AbsoluteSize.X, 1)
                local t   = math.clamp((x - abs) / w, 0, 1)
                applyValue(minVal + t * (maxVal - minVal), true)
            end

            local sliderBtn = newInst("TextButton", {
                Size                   = UDim2.new(0, 112, 0, 22),
                Position               = UDim2.new(1, -155, 0.5, -11),
                BackgroundTransparency = 1,
                Text                   = "",
                ZIndex                 = 3,
            }, r)

            sliderBtn.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1
                    or inp.UserInputType == Enum.UserInputType.Touch then
                    closeActiveDropdown()
                    draggingSlider = true
                    updateFromMouse(inp.Position.X)
                end
            end)

            UserInputService.InputChanged:Connect(function(inp)
                if draggingSlider and (inp.UserInputType == Enum.UserInputType.MouseMovement
                    or inp.UserInputType == Enum.UserInputType.Touch) then
                    updateFromMouse(inp.Position.X)
                end
            end)

            UserInputService.InputEnded:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1
                    or inp.UserInputType == Enum.UserInputType.Touch then
                    draggingSlider = false
                end
            end)

            return {
                Set = function(_, v, fireCb) applyValue(v, fireCb) end,
                Get = function() return val end,
            }
        end

        function tabApi:AddDropdown(cfg)
            cfg = cfg or {}
            local text     = cfg.Title or "Dropdown"
            local options  = cfg.Options or {}
            local selected = cfg.Default or options[1] or ""
            local callback = cfg.Callback

            local r = glassRow(32)
            rowLabel(r, text, nil, 138)

            local dd = newInst("TextButton", {
                Size                   = UDim2.new(0, 124, 0, 22),
                Position               = UDim2.new(1, -130, 0.5, -11),
                BackgroundColor3       = C.GlassPanel,
                BackgroundTransparency = 0.25,
                BorderSizePixel        = 0,
                Text                   = "",
            }, r)
            newInst("UICorner", { CornerRadius = UDim.new(0, 5) }, dd)
            local ddStroke = newInst("UIStroke", {
                Color           = C.Border,
                Thickness       = 1,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            }, dd)

            local ddText = newInst("TextLabel", {
                Size                   = UDim2.new(1, -20, 1, 0),
                Position               = UDim2.new(0, 7, 0, 0),
                BackgroundTransparency = 1,
                Text                   = selected,
                TextColor3             = C.TextPri,
                TextSize               = 10,
                Font                   = Enum.Font.Gotham,
                TextXAlignment         = Enum.TextXAlignment.Left,
                TextTruncate           = Enum.TextTruncate.AtEnd,
            }, dd)

            local arrow = newInst("TextLabel", {
                Size                   = UDim2.new(0, 14, 1, 0),
                Position               = UDim2.new(1, -16, 0, 0),
                BackgroundTransparency = 1,
                Text                   = "▾",
                TextColor3             = C.TextSec,
                TextSize               = 10,
                Font                   = Enum.Font.Gotham,
            }, dd)

            local listFrame = nil
            local outsideConn = nil

            local function closeMenu()
                if listFrame then
                    listFrame:Destroy()
                    listFrame = nil
                end
                if outsideConn then
                    outsideConn:Disconnect()
                    outsideConn = nil
                end
                ddStroke.Color = C.Border
                arrow.Text = "▾"
            end

            local function setSelected(opt, fireCb)
                selected = opt
                ddText.Text = opt
                if fireCb then
                    notify(text .. ": " .. opt, accentColor)
                    if callback then callback(opt) end
                end
            end

            dd.MouseButton1Click:Connect(function()
                if listFrame then
                    closeActiveDropdown()
                    return
                end

                closeActiveDropdown()
                activeDropdownClose = closeMenu
                ddStroke.Color = accentColor
                arrow.Text = "▴"

                local absPos  = dd.AbsolutePosition
                local absSize = dd.AbsoluteSize
                local itemH   = 23
                local totalH  = #options * itemH + 6
                local screen  = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 450)

                local spawnY = absPos.Y + absSize.Y + 4
                if spawnY + totalH > screen.Y - 8 then
                    spawnY = absPos.Y - totalH - 4
                end

                listFrame = newInst("Frame", {
                    Size                   = UDim2.new(0, absSize.X, 0, totalH),
                    Position               = UDim2.new(0, absPos.X, 0, spawnY),
                    BackgroundColor3       = C.GlassPopup,
                    BackgroundTransparency = 0.08,
                    BorderSizePixel        = 0,
                    ZIndex                 = 55,
                }, OverlayLayer)
                newInst("UICorner", { CornerRadius = UDim.new(0, 6) }, listFrame)
                newInst("UIStroke", {
                    Color           = accentColor,
                    Thickness       = 1,
                    Transparency    = 0.35,
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                }, listFrame)
                newInst("UIListLayout", {
                    Padding   = UDim.new(0, 1),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                }, listFrame)
                newInst("UIPadding", {
                    PaddingTop    = UDim.new(0, 3),
                    PaddingBottom = UDim.new(0, 3),
                    PaddingLeft   = UDim.new(0, 3),
                    PaddingRight  = UDim.new(0, 3),
                }, listFrame)

                for idx, opt in ipairs(options) do
                    local isSelected = (opt == selected)
                    local ob = newInst("TextButton", {
                        Size                   = UDim2.new(1, 0, 0, itemH - 1),
                        BackgroundColor3       = isSelected and accentColor or Color3.fromHex("#ffffff"),
                        BackgroundTransparency = isSelected and 0.78 or 1,
                        BorderSizePixel        = 0,
                        Text                   = "  " .. opt,
                        TextColor3             = isSelected and accentColor or C.TextPri,
                        TextSize               = 10,
                        Font                   = isSelected and Enum.Font.GothamSemibold or Enum.Font.Gotham,
                        TextXAlignment         = Enum.TextXAlignment.Left,
                        LayoutOrder            = idx,
                        ZIndex                 = 56,
                    }, listFrame)
                    newInst("UICorner", { CornerRadius = UDim.new(0, 4) }, ob)

                    ob.MouseEnter:Connect(function()
                        if opt ~= selected then
                            tween(ob, { BackgroundTransparency = 0.92 }, 0.1)
                        end
                    end)
                    ob.MouseLeave:Connect(function()
                        if opt ~= selected then
                            tween(ob, { BackgroundTransparency = 1 }, 0.1)
                        end
                    end)

                    ob.MouseButton1Click:Connect(function()
                        closeActiveDropdown()
                        setSelected(opt, true)
                    end)
                end

                outsideConn = UserInputService.InputBegan:Connect(function(inp)
                    if (inp.UserInputType == Enum.UserInputType.MouseButton1
                        or inp.UserInputType == Enum.UserInputType.Touch) and listFrame then
                        local mp = inp.Position
                        local lp, ls = listFrame.AbsolutePosition, listFrame.AbsoluteSize
                        local dp, ds = dd.AbsolutePosition, dd.AbsoluteSize
                        local inList = mp.X >= lp.X and mp.X <= lp.X + ls.X and mp.Y >= lp.Y and mp.Y <= lp.Y + ls.Y
                        local inBtn  = mp.X >= dp.X and mp.X <= dp.X + ds.X and mp.Y >= dp.Y and mp.Y <= dp.Y + ds.Y
                        if not inList and not inBtn then
                            closeActiveDropdown()
                        end
                    end
                end)
            end)

            return {
                Set = function(_, v, fireCb) setSelected(v, fireCb) end,
                Get = function() return selected end,
            }
        end

        function tabApi:AddButton(cfg)
            cfg = cfg or {}
            local text     = cfg.Title or "Button"
            local style    = cfg.Style or "ghost"
            local callback = cfg.Callback

            local bgMap = {
                primary = accentColor,
                ghost   = C.GlassCard,
                danger  = C.Danger,
            }
            local bgTransMap = { primary = 0.22, ghost = 0.42, danger = 0.82 }
            local txtMap = {
                primary = Color3.new(1, 1, 1),
                ghost   = C.TextPri,
                danger  = C.Danger,
            }

            local btn = newInst("TextButton", {
                Size                   = UDim2.new(1, 0, 0, 28),
                BackgroundColor3       = bgMap[style] or bgMap.ghost,
                BackgroundTransparency = bgTransMap[style] or 0.42,
                BorderSizePixel        = 0,
                Text                   = text,
                TextColor3             = txtMap[style] or C.TextPri,
                TextSize               = 10,
                Font                   = Enum.Font.GothamSemibold,
                LayoutOrder            = nextOrder(),
            }, pane)
            newInst("UICorner", { CornerRadius = UDim.new(0, 6) }, btn)

            if style == "primary" then
                bindAccent(function(c3)
                    btn.BackgroundColor3 = c3
                end)
            else
                newInst("UIStroke", {
                    Color           = style == "danger" and C.Danger or C.Border,
                    Thickness       = 1,
                    Transparency    = style == "danger" and 0.55 or 0.6,
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                }, btn)
            end

            btn.MouseButton1Click:Connect(function()
                closeActiveDropdown()
                if callback then callback() end
            end)
            btn.MouseEnter:Connect(function()
                tween(btn, { BackgroundTransparency = math.max((bgTransMap[style] or 0.42) - 0.12, 0.05) }, 0.12)
            end)
            btn.MouseLeave:Connect(function()
                tween(btn, { BackgroundTransparency = bgTransMap[style] or 0.42 }, 0.12)
            end)
            return btn
        end

        function tabApi:AddTextbox(cfg)
            cfg = cfg or {}
            local label       = cfg.Title or "Input"
            local placeholder = cfg.Placeholder or "enter value..."
            local defaultVal  = cfg.Default or ""
            local callback    = cfg.Callback

            local f = newInst("Frame", {
                Size                   = UDim2.new(1, 0, 0, 48),
                BackgroundTransparency = 1,
                LayoutOrder            = nextOrder(),
            }, pane)
            newInst("TextLabel", {
                Size                   = UDim2.new(1, 0, 0, 16),
                BackgroundTransparency = 1,
                Text                   = label,
                TextColor3             = C.TextSec,
                TextSize               = 10,
                Font                   = Enum.Font.GothamSemibold,
                TextXAlignment         = Enum.TextXAlignment.Left,
            }, f)
            local tb = newInst("TextBox", {
                Size                   = UDim2.new(1, 0, 0, 28),
                Position               = UDim2.new(0, 0, 0, 18),
                BackgroundColor3       = C.GlassCard,
                BackgroundTransparency = 0.42,
                BorderSizePixel        = 0,
                Text                   = defaultVal,
                PlaceholderText        = placeholder,
                TextColor3             = C.TextPri,
                PlaceholderColor3      = C.TextMut,
                TextSize               = 10,
                Font                   = Enum.Font.Code,
                ClearTextOnFocus       = false,
                TextXAlignment         = Enum.TextXAlignment.Left,
            }, f)
            newInst("UICorner", { CornerRadius = UDim.new(0, 6) }, tb)
            local stroke = newInst("UIStroke", {
                Color           = C.Border,
                Thickness       = 1,
                Transparency    = 0.55,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            }, tb)
            newInst("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, tb)

            tb:GetPropertyChangedSignal("Text"):Connect(function()
                if callback then callback(tb.Text) end
            end)
            tb.Focused:Connect(function()
                closeActiveDropdown()
                tween(tb, { BackgroundTransparency = 0.25 }, 0.12)
                stroke.Color = accentColor
                stroke.Transparency = 0.15
            end)
            tb.FocusLost:Connect(function()
                tween(tb, { BackgroundTransparency = 0.42 }, 0.12)
                stroke.Color = C.Border
                stroke.Transparency = 0.55
            end)

            return {
                Set = function(_, v) tb.Text = tostring(v or "") end,
                Get = function() return tb.Text end,
            }
        end

        function tabApi:AddColorPicker(cfg)
            cfg = cfg or {}
            local text       = cfg.Title or "Color"
            local paletteKey = cfg.Palette or "Accent"
            local list       = cfg.Colors or PALETTES[paletteKey] or PALETTES.Accent
            local defaultHex = cfg.Default or list[1]
            local callback   = cfg.Callback

            local r = newInst("Frame", {
                Size                   = UDim2.new(1, 0, 0, 0),
                AutomaticSize          = Enum.AutomaticSize.Y,
                BackgroundColor3       = C.GlassCard,
                BackgroundTransparency = 0.42,
                BorderSizePixel        = 0,
                LayoutOrder            = nextOrder(),
            }, pane)
            newInst("UICorner", { CornerRadius = UDim.new(0, 6) }, r)
            newInst("UIStroke", {
                Color           = C.Border,
                Thickness       = 1,
                Transparency    = 0.65,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            }, r)
            newInst("UIPadding", {
                PaddingTop    = UDim.new(0, 6),
                PaddingBottom = UDim.new(0, 7),
                PaddingLeft   = UDim.new(0, 9),
                PaddingRight  = UDim.new(0, 9),
            }, r)
            newInst("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder     = Enum.SortOrder.LayoutOrder,
                Padding       = UDim.new(0, 5),
            }, r)

            newInst("TextLabel", {
                Size                   = UDim2.new(1, 0, 0, 14),
                BackgroundTransparency = 1,
                Text                   = text,
                TextColor3             = C.TextPri,
                TextSize               = 11,
                Font                   = Enum.Font.GothamSemibold,
                TextXAlignment         = Enum.TextXAlignment.Left,
                LayoutOrder            = 1,
            }, r)

            local swatchHolder = newInst("Frame", {
                Size                   = UDim2.new(1, 0, 0, 0),
                AutomaticSize          = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                BorderSizePixel        = 0,
                LayoutOrder            = 2,
            }, r)

            local grid = newInst("UIGridLayout", {
                CellSize            = UDim2.new(0, 18, 0, 18),
                CellPadding         = UDim2.new(0, 6, 0, 6),
                FillDirection       = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Left,
                VerticalAlignment   = Enum.VerticalAlignment.Top,
                SortOrder           = Enum.SortOrder.LayoutOrder,
            }, swatchHolder)

            local swatches = {}
            local currentHex = defaultHex

            local function setActive(hex, triggerCallback)
                currentHex = hex
                for _, s in pairs(swatches) do
                    local isActive = (s.Name == hex)
                    local stroke = s:FindFirstChildOfClass("UIStroke")
                    if stroke then
                        stroke.Transparency = isActive and 0 or 1
                    end
                    tween(s, {
                        BackgroundTransparency = isActive and 0 or 0.15,
                    }, 0.12)
                end
                if triggerCallback and callback then
                    callback(Color3.fromHex(hex), hex)
                end
            end

            for idx, hex in ipairs(list) do
                local s = newInst("TextButton", {
                    Name             = string.lower(hex),
                    Size             = UDim2.new(0, 18, 0, 18),
                    BackgroundColor3 = Color3.fromHex(hex),
                    BorderSizePixel  = 0,
                    Text             = "",
                    LayoutOrder      = idx,
                }, swatchHolder)
                newInst("UICorner", { CornerRadius = UDim.new(0, 5) }, s)
                newInst("UIStroke", {
                    Color           = Color3.new(1, 1, 1),
                    Thickness       = 1.8,
                    Transparency    = 1,
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                }, s)
                s.MouseButton1Click:Connect(function()
                    closeActiveDropdown()
                    setActive(string.lower(hex), true)
                end)
                swatches[string.lower(hex)] = s
            end

            grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                swatchHolder.Size = UDim2.new(1, 0, 0, grid.AbsoluteContentSize.Y)
            end)

            setActive(string.lower(defaultHex), false)

            return {
                Set = function(_, hex, triggerCb)
                    local normalized = string.lower(hex)
                    if swatches[normalized] then
                        setActive(normalized, triggerCb)
                    end
                end,
                Get = function() return Color3.fromHex(currentHex), currentHex end,
            }
        end

        return tabApi
    end

    return windowApi
end

return Library
