Locations = {}

Locations.TrailerData = {
    ['fuel'] = {
        name = "Gasoline Tanker",
        model = `tanker`,
        truck = `phantom`,
        price = 300,
        xp = 25,
        destinations = {
            {label = "Gas Station 1", coords = vector3(49.2, 2778.1, 58.0)},
            {label = "Gas Station 2", coords = vector3(200.1, -1500.4, 29.0)}
        }
    },
    ['logs'] = {
        name = "Log Transport",
        model = `trailerlogs`,
        truck = `phantom`,
        price = 450,
        xp = 40,
        destinations = {
            {label = "Lumber Yard 1", coords = vector3(-563.2, 5342.2, 70.5)},
            {label = "Lumber Yard 2", coords = vector3(1200.5, 2750.3, 38.0)}
        }
    },
    ['containers'] = {
        name = "Heavy Containers",
        model = `docktrailer`,
        truck = `hauler`,
        price = 600,
        xp = 60,
        destinations = {
            {label = "Port 1", coords = vector3(-880.2, -2370.5, 13.0)},
            {label = "Port 2", coords = vector3(810.3, -2400.4, 28.5)}
        }
    }
}