/**
 * patch-flutter-url.js
 *
 * Reads the active ngrok tunnel URL from the ngrok local API (localhost:4040)
 * and patches water_meter_app/lib/core/constants.dart with it.
 *
 * Usage:
 *   node scripts/patch-flutter-url.js
 *   npm run patch-url
 *
 * Run this after `npm run pm2:start` once ngrok has had a few seconds to connect.
 */

const http  = require('http');
const fs    = require('fs');
const path  = require('path');

const CONSTANTS_DART = path.join(
    __dirname, '..', 'water_meter_app', 'lib', 'core', 'constants.dart'
);

const NGROK_API = 'http://127.0.0.1:4040/api/tunnels';

function fetchNgrokUrl() {
    return new Promise((resolve, reject) => {
        http.get(NGROK_API, (res) => {
            let data = '';
            res.on('data', (chunk) => { data += chunk; });
            res.on('end', () => {
                try {
                    const json = JSON.parse(data);
                    const tunnels = json.tunnels || [];
                    // Prefer the https tunnel
                    const tunnel = tunnels.find(t => t.proto === 'https') || tunnels[0];
                    if (!tunnel) return reject(new Error('No active tunnels found. Is ngrok running?'));
                    resolve(tunnel.public_url);
                } catch (e) {
                    reject(new Error(`Failed to parse ngrok API response: ${e.message}`));
                }
            });
        }).on('error', (e) => {
            reject(new Error(
                `Cannot reach ngrok local API at ${NGROK_API}.\n` +
                `Make sure ngrok is running (npm run pm2:start or ngrok http 3000).\n` +
                `Original error: ${e.message}`
            ));
        });
    });
}

function patchDart(ngrokUrl) {
    const apiUrl = `${ngrokUrl}/api`;
    const original = fs.readFileSync(CONSTANTS_DART, 'utf8');

    // Target only the else (mobile) branch.
    // Matches: } else {\n  // any comment\n  return 'OLD_URL';\n
    const mobileRegex = /(} else \{[^}]*?return\s+')(https?:\/\/[^']+)(';\s*\n)/s;

    if (!mobileRegex.test(original)) {
        console.warn('⚠  Could not find the mobile else-branch in constants.dart.');
        console.warn(`   Set the mobile URL manually to: '${apiUrl}'`);
        return;
    }

    const updated = original.replace(mobileRegex, (match, prefix, oldUrl, suffix) => {
        console.log(`  Old mobile URL: ${oldUrl}`);
        console.log(`  New mobile URL: ${apiUrl}`);
        return `${prefix}${apiUrl}${suffix}`;
    });

    fs.writeFileSync(CONSTANTS_DART, updated, 'utf8');
    console.log(`\n✓ constants.dart patched → ${apiUrl}`);
    console.log('  Rebuild the APK (flutter build apk) or hot-restart to apply.\n');
}

(async () => {
    console.log('Fetching ngrok tunnel URL...');
    try {
        const url = await fetchNgrokUrl();
        console.log(`ngrok public URL: ${url}`);
        patchDart(url);
    } catch (err) {
        console.error(`\n✗ ${err.message}\n`);
        process.exit(1);
    }
})();
