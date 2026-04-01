/**
 * Water tariff rates per customer category (VAT exclusive).
 * Source: WASAC Rwanda Water Tariff Schedule.
 *
 * VAT rate: 18%
 */

const VAT_RATE = 0.18;

const TARIFFS = {
    'PUBLIC TAP': {
        type: 'flat',
        rate: 323, // RWF per m³
    },
    'RESIDENTIAL': {
        type: 'progressive',
        bands: [
            { upTo: 5,        rate: 340 },
            { upTo: 20,       rate: 720 },
            { upTo: 50,       rate: 845 },
            { upTo: Infinity, rate: 877 },
        ],
    },
    'NON RESIDENTIAL': {
        type: 'progressive',
        bands: [
            { upTo: 50,       rate: 877 },
            { upTo: Infinity, rate: 895 },
        ],
    },
    'INDUSTRIES': {
        type: 'flat',
        rate: 736, // RWF per m³
    },
};

module.exports = { TARIFFS, VAT_RATE };
