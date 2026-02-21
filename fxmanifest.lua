fx_version 'cerulean'
game 'gta5'

author 'Amine'
description 'Trucker Job with trailers, NPC interaction and ox_lib support'
version '1.0.0'

-- Dependencies
shared_script 'config.lua'
shared_script 'locations.lua'

client_scripts {
    '@ox_lib/init.lua',
    'client.lua'
}

server_scripts {
    '@ox_lib/init.lua',
    '@oxmysql/lib/MySQL.lua', -- This defines the global MySQL variable
    'server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/images/*',
    'html/images/**/*.png', -- The ** means "all subfolders"
    'html/images/trailers/*.png'
}

dependencies {
    'ox_lib',
    'ox_inventory',
    'ox_target'
}
