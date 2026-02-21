Config = Config or {}

Config.JobPool = {
    { 
        name = "Fuel Delivery", 
        type = "fuel", 
        img = "images/trailers/tanker.png", 
        basePrice = 500, 
        minLevel = 1 
    },
    { 
        name = "Logging Transport", 
        type = "logs", 
        img = "images/trailers/trailers3.png", 
        basePrice = 750, 
        minLevel = 2 
    },
    { 
        name = "Industrial Containers", 
        type = "containers", 
        img = "images/trailers/docktrailer.png", 
        basePrice = 1200, 
        minLevel = 3 
    },
}

Config.MaxDailyJobs = 5 -- How many random jobs to show in the list
