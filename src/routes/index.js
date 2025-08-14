const express = require('express');
const router = express.Router();

// Import route modules
const userRoutes = require('./user.routes');
const listingRoutes = require('./listing.routes');
const tradeRoutes = require('./trade.routes');
const messageRoutes = require('./message.routes');
const ratingRoutes = require('./rating.routes');

// Use route modules
router.use('/users', userRoutes);
router.use('/listings', listingRoutes);
router.use('/trades', tradeRoutes);
router.use('/messages', messageRoutes);
router.use('/ratings', ratingRoutes);

module.exports = router;