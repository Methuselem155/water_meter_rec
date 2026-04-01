const mongoose = require('mongoose');
const bcrypt = require('bcrypt');
const User = require('./models/User');
require('dotenv').config();

const createAdmin = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        const salt = await bcrypt.genSalt(10);
        const passwordHash = await bcrypt.hash('admin123', salt);
        
        await User.findOneAndUpdate(
            { phoneNumber: '0700000000' },
            {
                accountNumber: 'ADMIN999',
                fullName: 'System Admin',
                phoneNumber: '0700000000',
                passwordHash: passwordHash,
                role: 'admin',
                category: 'RESIDENTIAL'
            },
            { upsert: true, new: true }
        );
        console.log('Admin user created/updated successfully. Phone: 0700000000, Pass: admin123');
        process.exit(0);
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
};

createAdmin();
