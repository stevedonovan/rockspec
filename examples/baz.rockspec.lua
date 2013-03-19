package('baz','0.5')

depends
    :when 'win32':on 'winapi'
    :otherwise 'unix':on 'luaposix'
    
Lua.install.script 'baz'


