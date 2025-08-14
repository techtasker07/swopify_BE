const express = require('express');
const router = express.Router();
const userController = require('../controllers/user.controller');
const authMiddleware = require('../middlewares/auth.middleware');

// Public routes
router.post('/register', userController.register);
router.post('/login', userController.login);

// Protected routes
router.get('/profile', authMiddleware, userController.getProfile);
router.put('/profile', authMiddleware, userController.updateProfile);
router.post('/verify', authMiddleware, userController.verifyUser);
router.get('/:id', authMiddleware, userController.getUserById);
router.get('/:id/ratings', authMiddleware, userController.getUserRatings);

module.exports = router;