const express = require('express');
const router = express.Router();
const messageController = require('../controllers/message.controller');
const authMiddleware = require('../middlewares/auth.middleware');
const upload = require('../middlewares/upload.middleware');

// All message routes are protected
router.post('/', authMiddleware, upload.single('media'), messageController.sendMessage);
router.get('/conversations', authMiddleware, messageController.getUserConversations);
router.get('/conversation/:conversationId', authMiddleware, messageController.getConversationMessages);
router.post('/read/:messageId', authMiddleware, messageController.markMessageAsRead);

module.exports = router;