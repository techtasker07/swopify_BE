const express = require('express');
const router = express.Router();
const ratingController = require('../controllers/rating.controller');
const authMiddleware = require('../middlewares/auth.middleware');

// All rating routes are protected
router.post('/:userId', authMiddleware, ratingController.rateUser);
router.get('/user/:userId', authMiddleware, ratingController.getUserRatings);
router.get('/stats/:userId', authMiddleware, ratingController.getUserRatingStats);

module.exports = router;