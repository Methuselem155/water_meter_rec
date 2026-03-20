const ocrService = require('./services/ocrService');
const fs = require('fs');
const path = require('path');

async function testAll() {
    const uploadsDir = path.join(__dirname, 'uploads');
    const files = fs.readdirSync(uploadsDir).filter(f => f.endsWith('.jpg') || f.endsWith('.png'));
    
    for (const file of files) {
        if (file === 'test.jpg' || file === 'test2.png') continue;
        const imgPath = path.join(uploadsDir, file);
        console.log(`\n\nTesting image: ${file}`);
        try {
            const result = await ocrService.processImage(imgPath);
            console.log(JSON.stringify(result, null, 2));
        } catch (err) {
            console.error(err.message);
        }
    }
}

testAll();
