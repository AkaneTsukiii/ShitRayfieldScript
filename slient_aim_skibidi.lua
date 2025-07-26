-- Universal Silent Aim - Rayfield Edition
-- Converted from LinoriaLib to Rayfield GUI for mobile compatibility
-- Original by Averiias, Stefanuk12, xaxa

-- Init
if not game:IsLoaded() then
    game.Loaded:Wait()
end

if not syn or not protectgui then
    getgenv().protectgui = function() end
end

-- Settings
local SilentAimSettings = {
    Enabled = false,
    ClassName = "Universal Silent Aim - Rayfield Edition",
    ToggleKey = "RightAlt",
    TeamCheck = false,
    VisibleCheck = false,
    TargetPart = "HumanoidRootPart",
    SilentAimMethod = "Raycast",
    FOVRadius = 130,
    FOVVisible = false,
    ShowSilentAimTarget = false,
    MouseHitPrediction = false,
    MouseHitPredictionAmount = 0.165,
    HitChance = 100
}

-- Variables
getgenv().SilentAimSettings = SilentAimSettings
local MainFileName = "UniversalSilentAim_Rayfield"

-- Services
local Camera = workspace.CurrentCamera
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Service Functions
local GetChildren = game.GetChildren
local GetPlayers = Players.GetPlayers
local WorldToScreen = Camera.WorldToScreenPoint
local WorldToViewportPoint = Camera.WorldToViewportPoint
local GetPartsObscuringTarget = Camera.GetPartsObscuringTarget
local FindFirstChild = game.FindFirstChild
local RenderStepped = RunService.RenderStepped
local GuiInset = GuiService.GetGuiInset
local GetMouseLocation = UserInputService.GetMouseLocation

local resume = coroutine.resume
local create = coroutine.create

-- Constants
local ValidTargetParts = {"Head", "HumanoidRootPart"}
local PredictionAmount = 0.165

-- Drawing Objects
local mouse_box = Drawing.new("Square")
mouse_box.Visible = false
mouse_box.ZIndex = 999
mouse_box.Color = Color3.fromRGB(54, 57, 241)
mouse_box.Thickness = 20
mouse_box.Size = Vector2.new(20, 20)
mouse_box.Filled = true

local fov_circle = Drawing.new("Circle")
fov_circle.Thickness = 1
fov_circle.NumSides = 100
fov_circle.Radius = 180
fov_circle.Filled = false
fov_circle.Visible = false
fov_circle.ZIndex = 999
fov_circle.Transparency = 1
fov_circle.Color = Color3.fromRGB(54, 57, 241)

-- Expected Arguments for Ray Methods
local ExpectedArguments = {
    FindPartOnRayWithIgnoreList = {
        ArgCountRequired = 3,
        Args = {
            "Instance", "Ray", "table", "boolean", "boolean"
        }
    },
    FindPartOnRayWithWhitelist = {
        ArgCountRequired = 3,
        Args = {
            "Instance", "Ray", "table", "boolean"
        }
    },
    FindPartOnRay = {
        ArgCountRequired = 2,
        Args = {
            "Instance", "Ray", "Instance", "boolean", "boolean"
        }
    },
    Raycast = {
        ArgCountRequired = 3,
        Args = {
            "Instance", "Vector3", "Vector3", "RaycastParams"
        }
    }
}

-- Utility Functions
function CalculateChance(Percentage)
    Percentage = math.floor(Percentage)
    local chance = math.floor(Random.new().NextNumber(Random.new(), 0, 1) * 100) / 100
    return chance <= Percentage / 100
end

-- File Handling
do
    if not isfolder(MainFileName) then
        makefolder(MainFileName)
    end
    
    if not isfolder(string.format("%s/%s", MainFileName, tostring(game.PlaceId))) then
        makefolder(string.format("%s/%s", MainFileName, tostring(game.PlaceId)))
    end
end

local function GetFiles()
    local Files = listfiles(string.format("%s/%s", MainFileName, tostring(game.PlaceId)))
    local out = {}
    for i = 1, #Files do
        local file = Files[i]
        if file:sub(-4) == '.lua' then
            local pos = file:find('.lua', 1, true)
            local start = pos
            local char = file:sub(pos, pos)
            while char ~= '/' and char ~= '\\' and char ~= '' do
                pos = pos - 1
                char = file:sub(pos, pos)
            end
            if char == '/' or char == '\\' then
                table.insert(out, file:sub(pos + 1, start - 1))
            end
        end
    end
    return out
end

local function UpdateFile(FileName)
    assert(FileName and type(FileName) == "string", "Invalid filename")
    writefile(string.format("%s/%s/%s.lua", MainFileName, tostring(game.PlaceId), FileName), HttpService:JSONEncode(SilentAimSettings))
end

local function LoadFile(FileName)
    assert(FileName and type(FileName) == "string", "Invalid filename")
    local File = string.format("%s/%s/%s.lua", MainFileName, tostring(game.PlaceId), FileName)
    local ConfigData = HttpService:JSONDecode(readfile(File))
    for Index, Value in next, ConfigData do
        SilentAimSettings[Index] = Value
    end
end

-- Core Functions
local function getPositionOnScreen(Vector)
    local Vec3, OnScreen = WorldToScreen(Camera, Vector)
    return Vector2.new(Vec3.X, Vec3.Y), OnScreen
end

local function ValidateArguments(Args, RayMethod)
    local Matches = 0
    if #Args < RayMethod.ArgCountRequired then
        return false
    end
    for Pos, Argument in next, Args do
        if typeof(Argument) == RayMethod.Args[Pos] then
            Matches = Matches + 1
        end
    end
    return Matches >= RayMethod.ArgCountRequired
end

local function getDirection(Origin, Position)
    return (Position - Origin).Unit * 1000
end

local function getMousePosition()
    return GetMouseLocation(UserInputService)
end

local function IsPlayerVisible(Player)
    local PlayerCharacter = Player.Character
    local LocalPlayerCharacter = LocalPlayer.Character

    if not (PlayerCharacter or LocalPlayerCharacter) then return end

    local PlayerRoot = FindFirstChild(PlayerCharacter, SilentAimSettings.TargetPart) or FindFirstChild(PlayerCharacter, "HumanoidRootPart")

    if not PlayerRoot then return end

    local CastPoints, IgnoreList = {PlayerRoot.Position, LocalPlayerCharacter, PlayerCharacter}, {LocalPlayerCharacter, PlayerCharacter}
    local ObscuringObjects = #GetPartsObscuringTarget(Camera, CastPoints, IgnoreList)

    return ((ObscuringObjects == 0 and true) or (ObscuringObjects > 0 and false))
end

local function getClosestPlayer()
    if not SilentAimSettings.TargetPart then return end
    local Closest
    local DistanceToMouse
    for _, Player in next, GetPlayers(Players) do
        if Player == LocalPlayer then continue end
        if SilentAimSettings.TeamCheck and Player.Team == LocalPlayer.Team then continue end

        local Character = Player.Character
        if not Character then continue end

        if SilentAimSettings.VisibleCheck and not IsPlayerVisible(Player) then continue end

        local HumanoidRootPart = FindFirstChild(Character, "HumanoidRootPart")
        local Humanoid = FindFirstChild(Character, "Humanoid")
        if not HumanoidRootPart or not Humanoid or Humanoid and Humanoid.Health <= 0 then continue end

        local ScreenPosition, OnScreen = getPositionOnScreen(HumanoidRootPart.Position)
        if not OnScreen then continue end

        local Distance = (getMousePosition() - ScreenPosition).Magnitude
        if Distance <= (DistanceToMouse or SilentAimSettings.FOVRadius or 2000) then
            Closest = ((SilentAimSettings.TargetPart == "Random" and Character[ValidTargetParts[math.random(1, #ValidTargetParts)]]) or Character[SilentAimSettings.TargetPart])
            DistanceToMouse = Distance
        end
    end
    return Closest
end

-- Load Rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Create Window
local Window = Rayfield:CreateWindow({
    Name = "Universal Silent Aim - Rayfield",
    Icon = 0,
    LoadingTitle = "Universal Silent Aim",
    LoadingSubtitle = "Mobile-Friendly Edition",
    Theme = "Default",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = MainFileName,
        FileName = "SilentAimConfig"
    },
    Discord = {
        Enabled = false,
        Invite = "",
        RememberJoins = true
    },
    KeySystem = false
})

-- Create Tabs
local MainTab = Window:CreateTab("Main", 4483362458)
local VisualsTab = Window:CreateTab("Visuals", 4483362458)
local PredictionTab = Window:CreateTab("Prediction", 4483362458)
local ConfigTab = Window:CreateTab("Config", 4483362458)

-- Main Section
local MainSection = MainTab:CreateSection("Silent Aim Settings")

local EnabledToggle = MainTab:CreateToggle({
    Name = "Silent Aim Enabled",
    CurrentValue = SilentAimSettings.Enabled,
    Flag = "SilentAimEnabled",
    Callback = function(Value)
        SilentAimSettings.Enabled = Value
        mouse_box.Visible = Value and SilentAimSettings.ShowSilentAimTarget
    end,
})

local TeamCheckToggle = MainTab:CreateToggle({
    Name = "Team Check",
    CurrentValue = SilentAimSettings.TeamCheck,
    Flag = "TeamCheck",
    Callback = function(Value)
        SilentAimSettings.TeamCheck = Value
    end,
})

local VisibleCheckToggle = MainTab:CreateToggle({
    Name = "Visible Check",
    CurrentValue = SilentAimSettings.VisibleCheck,
    Flag = "VisibleCheck",
    Callback = function(Value)
        SilentAimSettings.VisibleCheck = Value
    end,
})

local TargetPartDropdown = MainTab:CreateDropdown({
    Name = "Target Part",
    Options = {"Head", "HumanoidRootPart", "Random"},
    CurrentOption = SilentAimSettings.TargetPart,
    Flag = "TargetPart",
    Callback = function(Option)
        SilentAimSettings.TargetPart = Option
    end,
})

local MethodDropdown = MainTab:CreateDropdown({
    Name = "Silent Aim Method",
    Options = {
        "Raycast",
        "FindPartOnRay",
        "FindPartOnRayWithWhitelist",
        "FindPartOnRayWithIgnoreList",
        "Mouse.Hit/Target"
    },
    CurrentOption = SilentAimSettings.SilentAimMethod,
    Flag = "SilentAimMethod",
    Callback = function(Option)
        SilentAimSettings.SilentAimMethod = Option
    end,
})

local HitChanceSlider = MainTab:CreateSlider({
    Name = "Hit Chance",
    Range = {0, 100},
    Increment = 1,
    Suffix = "%",
    CurrentValue = SilentAimSettings.HitChance,
    Flag = "HitChance",
    Callback = function(Value)
        SilentAimSettings.HitChance = Value
    end,
})

-- Visuals Section
local VisualsSection = VisualsTab:CreateSection("FOV Circle")

local FOVVisibleToggle = VisualsTab:CreateToggle({
    Name = "Show FOV Circle",
    CurrentValue = SilentAimSettings.FOVVisible,
    Flag = "FOVVisible",
    Callback = function(Value)
        SilentAimSettings.FOVVisible = Value
        fov_circle.Visible = Value
    end,
})

local FOVRadiusSlider = VisualsTab:CreateSlider({
    Name = "FOV Circle Radius",
    Range = {0, 360},
    Increment = 1,
    Suffix = "px",
    CurrentValue = SilentAimSettings.FOVRadius,
    Flag = "FOVRadius",
    Callback = function(Value)
        SilentAimSettings.FOVRadius = Value
        fov_circle.Radius = Value
    end,
})

local TargetIndicatorSection = VisualsTab:CreateSection("Target Indicator")

local ShowTargetToggle = VisualsTab:CreateToggle({
    Name = "Show Silent Aim Target",
    CurrentValue = SilentAimSettings.ShowSilentAimTarget,
    Flag = "ShowSilentAimTarget",
    Callback = function(Value)
        SilentAimSettings.ShowSilentAimTarget = Value
        if not Value then
            mouse_box.Visible = false
        end
    end,
})

-- Prediction Section
local PredictionSection = PredictionTab:CreateSection("Mouse Hit Prediction")

local PredictionToggle = PredictionTab:CreateToggle({
    Name = "Mouse.Hit/Target Prediction",
    CurrentValue = SilentAimSettings.MouseHitPrediction,
    Flag = "MouseHitPrediction",
    Callback = function(Value)
        SilentAimSettings.MouseHitPrediction = Value
    end,
})

local PredictionAmountSlider = PredictionTab:CreateSlider({
    Name = "Prediction Amount",
    Range = {0.165, 1},
    Increment = 0.001,
    Suffix = "s",
    CurrentValue = SilentAimSettings.MouseHitPredictionAmount,
    Flag = "MouseHitPredictionAmount",
    Callback = function(Value)
        SilentAimSettings.MouseHitPredictionAmount = Value
        PredictionAmount = Value
    end,
})

-- Config Section
local ConfigSection = ConfigTab:CreateSection("Configuration Management")

local ConfigInput = ConfigTab:CreateInput({
    Name = "Configuration Name",
    PlaceholderText = "Enter config name...",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        -- Store for use in save/load functions
        getgenv().ConfigFileName = Text
    end,
})

local SaveConfigButton = ConfigTab:CreateButton({
    Name = "Save Configuration",
    Callback = function()
        local fileName = getgenv().ConfigFileName
        if fileName and fileName ~= "" then
            UpdateFile(fileName)
            Rayfield:Notify({
                Title = "Configuration Saved",
                Content = "Successfully saved configuration: " .. fileName,
                Duration = 3,
                Image = 4483362458,
            })
        else
            Rayfield:Notify({
                Title = "Error",
                Content = "Please enter a configuration name first",
                Duration = 3,
                Image = 4483362458,
            })
        end
    end,
})

local LoadConfigDropdown = ConfigTab:CreateDropdown({
    Name = "Load Configuration",
    Options = GetFiles(),
    CurrentOption = "",
    Flag = "LoadConfig",
    Callback = function(Option)
        if Option and Option ~= "" then
            pcall(function()
                LoadFile(Option)
                
                -- Update all UI elements with loaded values
                EnabledToggle:Set(SilentAimSettings.Enabled)
                TeamCheckToggle:Set(SilentAimSettings.TeamCheck)
                VisibleCheckToggle:Set(SilentAimSettings.VisibleCheck)
                TargetPartDropdown:Set(SilentAimSettings.TargetPart)
                MethodDropdown:Set(SilentAimSettings.SilentAimMethod)
                HitChanceSlider:Set(SilentAimSettings.HitChance)
                FOVVisibleToggle:Set(SilentAimSettings.FOVVisible)
                FOVRadiusSlider:Set(SilentAimSettings.FOVRadius)
                ShowTargetToggle:Set(SilentAimSettings.ShowSilentAimTarget)
                PredictionToggle:Set(SilentAimSettings.MouseHitPrediction)
                PredictionAmountSlider:Set(SilentAimSettings.MouseHitPredictionAmount)
                
                -- Update visual elements
                fov_circle.Radius = SilentAimSettings.FOVRadius
                fov_circle.Visible = SilentAimSettings.FOVVisible
                mouse_box.Visible = SilentAimSettings.Enabled and SilentAimSettings.ShowSilentAimTarget
                
                Rayfield:Notify({
                    Title = "Configuration Loaded",
                    Content = "Successfully loaded configuration: " .. Option,
                    Duration = 3,
                    Image = 4483362458,
                })
            end)
        end
    end,
})

local RefreshConfigsButton = ConfigTab:CreateButton({
    Name = "Refresh Config List",
    Callback = function()
        LoadConfigDropdown:Refresh(GetFiles())
    end,
})

-- Keybind for toggle (RightAlt)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.RightAlt then
        SilentAimSettings.Enabled = not SilentAimSettings.Enabled
        EnabledToggle:Set(SilentAimSettings.Enabled)
        mouse_box.Visible = SilentAimSettings.Enabled and SilentAimSettings.ShowSilentAimTarget
        
        Rayfield:Notify({
            Title = "Silent Aim",
            Content = "Silent Aim " .. (SilentAimSettings.Enabled and "Enabled" or "Disabled"),
            Duration = 2,
            Image = 4483362458,
        })
    end
end)

-- Visual Updates
resume(create(function()
    RenderStepped:Connect(function()
        -- Update target indicator
        if SilentAimSettings.ShowSilentAimTarget and SilentAimSettings.Enabled then
            local target = getClosestPlayer()
            if target then
                local Root = target.Parent.PrimaryPart or target
                local RootToViewportPoint, IsOnScreen = WorldToViewportPoint(Camera, Root.Position)
                
                mouse_box.Visible = IsOnScreen
                mouse_box.Position = Vector2.new(RootToViewportPoint.X, RootToViewportPoint.Y)
            else
                mouse_box.Visible = false
                mouse_box.Position = Vector2.new()
            end
        else
            mouse_box.Visible = false
        end

        -- Update FOV circle
        if SilentAimSettings.FOVVisible then
            fov_circle.Visible = true
            fov_circle.Position = getMousePosition()
        else
            fov_circle.Visible = false
        end
    end)
end))

-- Silent Aim Hooks
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(...)
    local Method = getnamecallmethod()
    local Arguments = {...}
    local self = Arguments[1]
    local chance = CalculateChance(SilentAimSettings.HitChance)
    
    if SilentAimSettings.Enabled and self == workspace and not checkcaller() and chance then
        if Method == "FindPartOnRayWithIgnoreList" and SilentAimSettings.SilentAimMethod == Method then
            if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRayWithIgnoreList) then
                local A_Ray = Arguments[2]
                local HitPart = getClosestPlayer()
                if HitPart then
                    local Origin = A_Ray.Origin
                    local Direction = getDirection(Origin, HitPart.Position)
                    Arguments[2] = Ray.new(Origin, Direction)
                    return oldNamecall(unpack(Arguments))
                end
            end
        elseif Method == "FindPartOnRayWithWhitelist" and SilentAimSettings.SilentAimMethod == Method then
            if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRayWithWhitelist) then
                local A_Ray = Arguments[2]
                local HitPart = getClosestPlayer()
                if HitPart then
                    local Origin = A_Ray.Origin
                    local Direction = getDirection(Origin, HitPart.Position)
                    Arguments[2] = Ray.new(Origin, Direction)
                    return oldNamecall(unpack(Arguments))
                end
            end
        elseif (Method == "FindPartOnRay" or Method == "findPartOnRay") and SilentAimSettings.SilentAimMethod:lower() == Method:lower() then
            if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRay) then
                local A_Ray = Arguments[2]
                local HitPart = getClosestPlayer()
                if HitPart then
                    local Origin = A_Ray.Origin
                    local Direction = getDirection(Origin, HitPart.Position)
                    Arguments[2] = Ray.new(Origin, Direction)
                    return oldNamecall(unpack(Arguments))
                end
            end
        elseif Method == "Raycast" and SilentAimSettings.SilentAimMethod == Method then
            if ValidateArguments(Arguments, ExpectedArguments.Raycast) then
                local A_Origin = Arguments[2]
                local HitPart = getClosestPlayer()
                if HitPart then
                    Arguments[3] = getDirection(A_Origin, HitPart.Position)
                    return oldNamecall(unpack(Arguments))
                end
            end
        end
    end
    return oldNamecall(...)
end))

-- Mouse.Hit/Target Hook
local oldIndex
oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, Index)
    if self == Mouse and not checkcaller() and SilentAimSettings.Enabled then
        local chance = CalculateChance(SilentAimSettings.HitChance)
        if chance and SilentAimSettings.SilentAimMethod == "Mouse.Hit/Target" then
            local HitPart = getClosestPlayer()
            if HitPart then
                if Index == "Hit" then
                    local Hit = HitPart.Position
                    if SilentAimSettings.MouseHitPrediction then
                        Hit = Hit + (HitPart.AssemblyLinearVelocity * PredictionAmount)
                    end
                    return CFrame.new(Hit)
                elseif Index == "Target" then
                    return HitPart
                elseif Index == "X" then
                    local Hit = HitPart.Position
                    if SilentAimSettings.MouseHitPrediction then
                        Hit = Hit + (HitPart.AssemblyLinearVelocity * PredictionAmount)
                    end
                    return Hit.X
                elseif Index == "Y" then
                    local Hit = HitPart.Position
                    if SilentAimSettings.MouseHitPrediction then
                        Hit = Hit + (HitPart.AssemblyLinearVelocity * PredictionAmount)
                    end
                    return Hit.Y
                elseif Index == "Z" then
                    local Hit = HitPart.Position
                    if SilentAimSettings.MouseHitPrediction then
                        Hit = Hit + (HitPart.AssemblyLinearVelocity * PredictionAmount)
                    end
                    return Hit.Z
                end
            end
        end
    end
    return oldIndex(self, Index)
end))

-- Load saved configuration
Rayfield:LoadConfiguration()

-- Startup notification
Rayfield:Notify({
    Title = "Universal Silent Aim",
    Content = "Successfully loaded! Press RightAlt to toggle.",
    Duration = 5,
    Image = 4483362458,
})
