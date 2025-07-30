fx_version 'cerulean'

game 'gta5'

author 'Jonirulah & Oasis Team'
description 'Vehicle Boosting'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
	'locale.lua',
}

client_scripts {
    'client/framework/*.lua',
    'client/client_editable.lua',
    'client/client.lua',
    'client/nui.lua',
}

server_scripts {
	'@mysql-async/lib/MySQL.lua',
    'server/framework/*.lua',
    'server/server_sql.lua',
    'server/server_editable.lua',
    'server/server.lua',
    'server/utils_editable.lua'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/**/*',
}

depencendies {
    '/onesync',
    'glow_minigames',
    'timer',
    'joni_tablet',
    't3_lockpick'
}