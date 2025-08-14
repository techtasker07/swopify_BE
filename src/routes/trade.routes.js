const express = require('express');
const router = express.Router();
const tradeController = require('../controllers/trade.controller');
const authMiddleware = require('../middlewares/auth.middleware');

// All trade routes are protected
router.post('/propose', authMiddleware, tradeController.proposeTrade);
router.get('/', authMiddleware, tradeController.getUserTrades);
router.get('/:id', authMiddleware, tradeController.getTradeById);
router.put('/:id/accept', authMiddleware, tradeController.acceptTrade);
router.put('/:id/reject', authMiddleware, tradeController.rejectTrade);
router.put('/:id/complete', authMiddleware, tradeController.completeTrade);
router.post('/match', authMiddleware, tradeController.findTradeMatches);
router.post('/multi-party', authMiddleware, tradeController.proposeMultiPartyTrade);

module.exports = router;