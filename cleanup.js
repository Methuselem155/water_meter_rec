#!/usr/bin/env node
/**
 * Cleanup script to remove old debug images and unnecessary files
 * Usage: node cleanup.js
 */

const fs = require('fs');
const path = require('path');

const cleanupDirs = [
    { path: './tmp', pattern: 'debug_preprocessed_*.jpg', description: 'Debug preprocessed images' },
];

const cleanup = async () => {
    console.log('\n========================================');
    console.log('CLEANUP SCRIPT');
    console.log('========================================\n');

    let totalDeleted = 0;

    for (const dir of cleanupDirs) {
        const fullPath = path.join(__dirname, dir.path);
        
        if (!fs.existsSync(fullPath)) {
            console.log(`⊘ Directory not found: ${fullPath}`);
            continue;
        }

        try {
            const files = fs.readdirSync(fullPath);
            const pattern = new RegExp(
                dir.pattern
                    .replace(/\*/g, '.*')
                    .replace(/\?/g, '.')
            );

            const filesToDelete = files.filter(f => pattern.test(f));

            if (filesToDelete.length === 0) {
                console.log(`⊘ No files matching "${dir.pattern}" in ${dir.path}/`);
                continue;
            }

            for (const file of filesToDelete) {
                const filePath = path.join(fullPath, file);
                fs.unlinkSync(filePath);
                totalDeleted++;
                console.log(`✓ Deleted: ${dir.path}/${file}`);
            }

            console.log(`  └─ Deleted ${filesToDelete.length} ${dir.description}\n`);

        } catch (error) {
            console.error(`✗ Error cleaning ${dir.path}: ${error.message}`);
        }
    }

    console.log('========================================');
    console.log(`Total files deleted: ${totalDeleted}`);
    console.log('========================================\n');
};

cleanup().catch(err => {
    console.error('✗ Cleanup failed:', err);
    process.exit(1);
});
