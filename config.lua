Config = {}

-- =========================
-- NPC SETTINGS
-- =========================
-- The ped you talk to to open the menu
Config.NPCModel = `s_m_m_trucker_01`
Config.NPCCoords = vector4(-1182.51, -2205.99, 13.18, 323.14)
Config.NPCAnimation = {"amb@world_human_clipboard@male@base", "base"}

Config.NPCBlip = {
    sprite = 477, -- Truck icon
    color = 5,    -- Yellow/Greenish
    scale = 0.8,
    name = "Truck Job"
}

-- =========================
-- JOBS SETTINGS
-- =========================
-- These are displayed in the NUI Dashboard
Config.Jobs = {
    { 
        id = 1, 
        name = "Gasoline Tanker", 
        type = "fuel", 
        streetNames = "Highway 21", 
        totalPrice = 300, 
        kmEarnings = 10, 
        imgSrc = "images/trailers/tanker.png", 
        level = 1, 
        distance = 50 
    },
    { 
        id = 2, 
        name = "Log Transport", 
        type = "logs", 
        streetNames = "Downtown", 
        totalPrice = 450, 
        kmEarnings = 15, 
        imgSrc = "images/trailers/trailers3.png", 
        level = 1, 
        distance = 80 
    },
    { 
        id = 3, 
        name = "Heavy Containers", 
        type = "containers", 
        streetNames = "Airport Road", 
        totalPrice = 600, 
        kmEarnings = 20, 
        imgSrc = "images/trailers/docktrailer.png", 
        level = 1, 
        distance = 120 
    },
    { 
        id = 4, 
        name = "Big Goods Delivery", 
        type = "biggoods", 
        streetNames = "Industrial Way", 
        totalPrice = 750, 
        kmEarnings = 25, 
        imgSrc = "images/trailers/trailers3.png", 
        level = 2, 
        distance = 150 
    },
    { 
        id = 5, 
        name = "Generic Freight", 
        type = "generic", 
        streetNames = "Paleto Blvd", 
        totalPrice = 200, 
        kmEarnings = 8, 
        imgSrc = "images/trailers/tanker.png", 
        level = 1, 
        distance = 40 
    }
}

-- =========================
-- TRUCKS & TRAILERS
-- =========================
-- Maps the cargo type to the physical models spawned in the world
Config.Trucks = {
    { name = "Fuel Truck", model = `phantom`, cargoType = "fuel", trailer = `tanker` },
    { name = "Log Truck", model = `phantom`, cargoType = "logs", trailer = `trailerlogs` },
    { name = "Container Truck", model = `phantom`, cargoType = "containers", trailer = `docktrailer` },
    { name = "Big Goods Truck", model = `hauler`, cargoType = "biggoods", trailer = `trailers3` },
    { name = "Generic Truck", model = `packer`, cargoType = "generic", trailer = `trailers` }
}

-- Automated Hash Mapping for the script logic
Config.TruckModels = {}
Config.TrailerModels = {}
for _, t in ipairs(Config.Trucks) do
    Config.TruckModels[t.cargoType] = t.model
    Config.TrailerModels[t.cargoType] = t.trailer
end

-- =========================
-- SPAWN SETTINGS
-- =========================
-- Main location where the truck spawns
Config.TruckSpawn = vector4(-1170.3165, -2210.9538, 13.1882, 328.8189)

-- Multiple points for trailers to support Convoy spawning without explosions
Config.TrailerSpawnPoints = {
    vector4(-1160.0, -2200.0, 13.0, 320.0),
    vector4(-1155.0, -2205.0, 13.0, 320.0),
    vector4(-1150.0, -2210.0, 13.0, 320.0),
    vector4(-1145.0, -2215.0, 13.0, 320.0),
}

-- =========================
-- DELIVERY POINTS
-- =========================
-- These must match the 'type' defined in Config.Jobs
Config.DeliveryPoints = {
    fuel = {
        { label = "Gas Station 1", coords = vector3(49.2, 2778.1, 58.0) },
        { label = "Gas Station 2", coords = vector3(200.1, -1500.4, 29.0) }
    },
    logs = {
        { label = "Lumber Yard 1", coords = vector3(-563.2, 5342.2, 70.5) },
        { label = "Lumber Yard 2", coords = vector3(1200.5, 2750.3, 38.0) }
    },
    containers = {
        { label = "Port 1", coords = vector3(-880.2, -2370.5, 13.0) },
        { label = "Port 2", coords = vector3(810.3, -2400.4, 28.5) }
    },
    biggoods = {
        { label = "Warehouse 1", coords = vector3(100.2, -300.0, 45.0) },
        { label = "Warehouse 2", coords = vector3(-200.3, -150.4, 34.0) }
    },
    generic = {
        { label = "Distribution Hub 1", coords = vector3(215.3, -810.2, 30.7) },
        { label = "Distribution Hub 2", coords = vector3(-1212.5, -331.1, 37.7) }
    }
}

-- =========================
-- BLIP SETTINGS
-- =========================
Config.DeliveryBlip = {
    sprite = 477, -- Truck icon
    color = 3,    -- Light Blue
    scale = 0.9,
    name = "Delivery Point"
}