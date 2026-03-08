/**
 * Defines the tiered pricing structure for water consumption.
 * Bands are evaluated sequentially.
 * 
 * Example interpretation:
 * - The first 5 units cost 0.50 each.
 * - The next 5 units (up to 10 total) cost 0.75 each.
 * - Any units beyond 10 cost 1.00 each.
 */
const tariffs = [
    { upTo: 5, rate: 0.5 },
    { upTo: 10, rate: 0.75 },
    { upTo: Infinity, rate: 1.0 }
];

module.exports = tariffs;
