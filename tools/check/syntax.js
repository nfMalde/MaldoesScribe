// Syntax check of every Lua file of the addon with luaparse (Lua 5.1, like the game).
const fs = require('fs');
const path = require('path');
const luaparse = require('luaparse');

const dir = process.argv[2];
let failed = 0;
for (const file of fs.readdirSync(dir).filter((f) => f.endsWith('.lua')).sort()) {
    const code = fs.readFileSync(path.join(dir, file), 'utf8');
    try {
        luaparse.parse(code, { luaVersion: '5.1', comments: false });
        console.log(`ok   ${file}`);
    } catch (error) {
        failed++;
        console.log(`FAIL ${file}: ${error.message}`);
    }
}
process.exit(failed ? 1 : 0);
