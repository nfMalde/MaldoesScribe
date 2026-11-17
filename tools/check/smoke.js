// Loads the addon in a Lua VM (fengari) with a tiny stand-in for the game's API, then runs test.lua.
const fs = require('fs');
const path = require('path');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');

const addonDir = process.argv[2];
const checkDir = __dirname;
const ADDON = 'MaldoesScribe';

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

function run(file, withArgs) {
    const code = fs.readFileSync(file, 'utf8');
    lua.lua_getglobal(L, to_luastring('debug'));
    lua.lua_getfield(L, -1, to_luastring('traceback'));
    lua.lua_remove(L, -2);
    const handler = lua.lua_gettop(L);
    const buffer = to_luastring(code);
    if (lauxlib.luaL_loadbuffer(L, buffer, buffer.length, to_luastring('@' + path.basename(file))) !== lua.LUA_OK) {
        throw new Error('load ' + file + ': ' + to_jsstring(lua.lua_tostring(L, -1)));
    }
    let nargs = 0;
    if (withArgs) {
        lua.lua_pushstring(L, to_luastring(ADDON));
        lua.lua_getglobal(L, to_luastring('__NS'));
        nargs = 2;
    }
    if (lua.lua_pcall(L, nargs, 0, handler) !== lua.LUA_OK) {
        throw new Error('run ' + file + ': ' + to_jsstring(lua.lua_tostring(L, -1)));
    }
    lua.lua_settop(L, handler - 1);
}

const toc = fs.readFileSync(path.join(addonDir, ADDON + '.toc'), 'utf8');
const files = toc.split(/\r?\n/).map((l) => l.trim()).filter((l) => l.endsWith('.lua'));

try {
    run(path.join(checkDir, 'stubs.lua'), false);
    for (const file of files) {
        run(path.join(addonDir, file), true);
        console.log('loaded ' + file);
    }
    run(path.join(checkDir, 'test.lua'), false);
    lua.lua_getglobal(L, to_luastring('TEST_FAILURES'));
    const failures = lua.lua_tointeger(L, -1);
    process.exit(failures ? 1 : 0);
} catch (error) {
    console.error(error.message);
    process.exit(2);
}
