// Every text key used in the code exists in English, and English and German have the same keys.
const fs = require('fs');
const path = require('path');

const dir = process.argv[2];
const locales = fs.readFileSync(path.join(dir, 'Locales.lua'), 'utf8');

function keysOf(block) {
    const start = locales.indexOf(`locales.${block} = {`);
    const end = locales.indexOf('\n}\n', start);
    const body = locales.slice(start, end);
    return new Set([...body.matchAll(/^\s+([A-Z][A-Z0-9_]*) = /gm)].map((m) => m[1]));
}
const en = keysOf('en');
const de = keysOf('de');
let failed = 0;
for (const key of en) if (!de.has(key)) { console.log(`missing in de: ${key}`); failed++; }
for (const key of de) if (!en.has(key)) { console.log(`missing in en: ${key}`); failed++; }

const used = new Set();
const patterns = [
    /\bL\.([A-Z][A-Z0-9_]*)/g,
    /\b(?:Text|Button)\([^,()]+, "([A-Z][A-Z0-9_]*)"/g,
    /\b(?:Check|Hint|Section|Row)\("([A-Z][A-Z0-9_]*)"/g,
    /\bkey = "([A-Z][A-Z0-9_]*)"/g,
    /\b(?:label|empty) = "([A-Z][A-Z0-9_]*)"/g,
];
for (const file of fs.readdirSync(dir).filter((f) => f.endsWith('.lua') && f !== 'Locales.lua')) {
    const code = fs.readFileSync(path.join(dir, file), 'utf8');
    for (const pattern of patterns) {
        for (const match of code.matchAll(pattern)) used.add(match[1]);
    }
}
for (const key of used) if (!en.has(key)) { console.log(`used but not defined: ${key}`); failed++; }
for (const key of en) if (!used.has(key)) console.log(`defined but unused: ${key}`);
console.log(`${used.size} keys used, ${en.size} defined, ${failed} problems`);
process.exit(failed ? 1 : 0);
