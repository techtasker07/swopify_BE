const express = require('express');
const router = express.Router();
const listingController = require('../controllers/listing.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const upload = require('../middlewares/upload.middleware');

// Public routes
router.get('/', listingController.getAllListings);
router.get('/:id', listingController.getListingById);
router.get('/category/:category', listingController.getListingsByCategory);

// Protected routes
router.post('/', authMiddleware, upload.array('images', 5), listingController.createListing);
router.put('/:id', authMiddleware, upload.array('images', 5), listingController.updateListing);
router.delete('/:id', authMiddleware, listingController.deleteListing);
router.get('/user/:userId', authMiddleware, listingController.getUserListings);

module.exports = router;