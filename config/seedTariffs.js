const Tariff = require('../models/Tariff');

const DEFAULT_TARIFFS = [
    {
        category: 'PUBLIC TAP',
        type: 'flat',
        rate: 323,
        bands: [],
        vatRate: 0.18,
    },
    {
        category: 'RESIDENTIAL',
        type: 'progressive',
        bands: [
            { upTo: 5, rate: 340 },
            { upTo: 20, rate: 720 },
            { upTo: 50, rate: 845 },
            { upTo: 999999, rate: 877 },
        ],
        vatRate: 0.18,
    },
    {
        category: 'NON RESIDENTIAL',
        type: 'progressive',
        bands: [
            { upTo: 50, rate: 877 },
            { upTo: 999999, rate: 895 },
        ],
        vatRate: 0.18,
    },
    {
        category: 'INDUSTRIES',
        type: 'flat',
        rate: 736,
        bands: [],
        vatRate: 0.18,
    },
];

async function seedTariffs() {
    const count = await Tariff.countDocuments();
    if (count > 0) return;

    await Tariff.insertMany(DEFAULT_TARIFFS);
    console.log('[Seed] Default WASAC tariffs inserted.');
}

module.exports = seedTariffs;
