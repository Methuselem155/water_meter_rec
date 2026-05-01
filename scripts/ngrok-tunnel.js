/**
 * PM2-managed ngrok tunnel wrapper.
 * Spawns `ngrok http 3000` as a child process so PM2 can manage it normally.
 */
const { spawn } = require('child_process');

const port = process.env.PORT || 3000;

const proc = spawn('ngrok', ['http', '--log=stdout', String(port)], {
    stdio: 'inherit',
    shell: true,   // required on Windows to resolve ngrok from PATH
});

proc.on('exit', (code) => {
    console.log(`[ngrok] process exited with code ${code}`);
    process.exit(code ?? 1);
});

process.on('SIGINT',  () => proc.kill('SIGINT'));
process.on('SIGTERM', () => proc.kill('SIGTERM'));
