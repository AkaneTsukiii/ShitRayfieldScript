--[[
    AirHub V2 - Rayfield Edition
    Universal Roblox Aimbot, ESP & Crosshair with ShiftLock
    
    Original AirHub-V2 by Exunys
    Rayfield GUI Integration & ShiftLock by AI Assistant
    
    Features:
    - Universal Aimbot V3 with ShiftLock support
    - CS:GO-styled ESP with chams
    - Customizable crosshair system
    - NEW: ShiftLock functionality for games without native support
    - Modern Rayfield GUI interface
    - Configuration saving/loading
]]

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

-- Variables
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Load Rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Load modules
local modules = {}
local moduleNames = {"Utils", "ConfigManager", "AimbotV3", "ESP", "Crosshair", "ShiftLock", "RayfieldGUI"}

-- Create module loader
local function loadModule(name)
    local success, module = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/Exunys/AirHub-V2/main/modules/" .. name .. ".lua"))()
    end)
    
    if success then
        return module
    else
        -- Fallback to local modules if GitHub fails
        warn("Failed to load " .. name .. " from GitHub, using local version")
        return require(script.modules[name])
    end
end

-- Load all modules
for _, moduleName in ipairs(moduleNames) do
    modules[moduleName] = loadModule(moduleName)
end

-- Initialize core systems
local Utils = modules.Utils
local ConfigManager = modules.ConfigManager
local AimbotV3 = modules.AimbotV3
local ESP = modules.ESP
local Crosshair = modules.Crosshair
local ShiftLock = modules.ShiftLock
local RayfieldGUI = modules.RayfieldGUI

-- Configuration
local Config = {
    -- Aimbot settings
    Aimbot = {
        Enabled = false,
        TargetPart = "Head",
        Sensitivity = 0.5,
        FOV = 90,
        Smoothness = 1,
        VisibilityCheck = true,
        TeamCheck = true,
        MaxDistance = 1000,
        PredictMovement = false,
        ShiftLockMode = false -- NEW: ShiftLock integration
    },
    
    -- ESP settings
    ESP = {
        Enabled = false,
        ShowNames = true,
        ShowDistance = true,
        ShowHealth = true,
        ShowBoxes = true,
        ShowChams = false,
        MaxDistance = 1000,
        TeamCheck = true,
        Colors = {
            Enemy = Color3.fromRGB(255, 0, 0),
            Team = Color3.fromRGB(0, 255, 0),
            Chams = Color3.fromRGB(255, 100, 100)
        }
    },
    
    -- Crosshair settings
    Crosshair = {
        Enabled = false,
        Size = 10,
        Thickness = 2,
        Gap = 5,
        Color = Color3.fromRGB(255, 255, 255),
        Transparency = 0,
        CenterDot = true,
        DotSize = 2
    },
    
    -- NEW: ShiftLock settings
    ShiftLock = {
        Enabled = false,
        ForceCenter = true,
        CameraLock = true,
        CompatibilityMode = true,
        Sensitivity = 0.8
    },
    
    -- GUI settings
    GUI = {
        ToggleKey = Enum.KeyCode.RightShift,
        Theme = "Default"
    }
}

-- Initialize systems
local function initializeSystems()
    -- Load saved configuration
    local savedConfig = ConfigManager:LoadConfig()
    if savedConfig then
        for category, settings in pairs(savedConfig) do
            if Config[category] then
                for setting, value in pairs(settings) do
                    Config[category][setting] = value
                end
            end
        end
    end
    
    -- Initialize modules with config
    Utils:Initialize()
    AimbotV3:Initialize(Config.Aimbot)
    ESP:Initialize(Config.ESP)
    Crosshair:Initialize(Config.Crosshair)
    ShiftLock:Initialize(Config.ShiftLock) -- NEW: Initialize ShiftLock
    
    -- Initialize Rayfield GUI
    RayfieldGUI:Initialize(Config, {
        Aimbot = AimbotV3,
        ESP = ESP,
        Crosshair = Crosshair,
        ShiftLock = ShiftLock, -- NEW: Pass ShiftLock to GUI
        ConfigManager = ConfigManager,
        Utils = Utils
    })
    
    print("AirHub V2 - Rayfield Edition loaded successfully!")
    print("Press " .. Config.GUI.ToggleKey.Name .. " to open/close GUI")
end

-- Handle GUI toggle
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Config.GUI.ToggleKey then
        RayfieldGUI:Toggle()
    end
end)

-- Main initialization
local function main()
    -- Check if game is loaded
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end
    
    -- Wait for character
    if LocalPlayer.Character then
        initializeSystems()
    else
        LocalPlayer.CharacterAdded:Wait()
        wait(1) -- Additional wait for character to fully load
        initializeSystems()
    end
end

-- Start the script
main()
