const { Trade, Listing, User } = require('../models');
const { Op } = require('sequelize');
const { sequelize } = require('../config/database');

const tradeController = {
  // Propose a new trade
  proposeTrade: async (req, res) => {
    try {
      const proposerId = req.userId;
      const { receiverId, proposerListingId, receiverListingId, tradeCoinAmount, notes } = req.body;
      
      // Validate listings
      const proposerListing = await Listing.findByPk(proposerListingId);
      const receiverListing = await Listing.findByPk(receiverListingId);
      
      if (!proposerListing || !receiverListing) {
        return res.status(404).json({ message: 'One or both listings not found' });
      }
      
      // Check if proposer owns their listing
      if (proposerListing.userId !== proposerId) {
        return res.status(403).json({ message: 'You do not own the proposer listing' });
      }
      
      // Check if receiver owns their listing
      if (receiverListing.userId !== receiverId) {
        return res.status(403).json({ message: 'Receiver does not own the receiver listing' });
      }
      
      // Check if both listings are available
      if (!proposerListing.isAvailable || !receiverListing.isAvailable) {
        return res.status(400).json({ message: 'One or both listings are not available for trade' });
      }
      
      // Create trade
      const newTrade = await Trade.create({
        proposerId,
        receiverId,
        proposerListingId,
        receiverListingId,
        status: 'proposed',
        type: 'direct',
        tradeCoinAmount: tradeCoinAmount || 0,
        notes
      });
      
      return res.status(201).json({
        message: 'Trade proposed successfully',
        trade: newTrade
      });
    } catch (error) {
      console.error('Propose trade error:', error);
      return res.status(500).json({ message: 'Server error', error: error.message });
    }
  },
  
  // Get user trades
  getUserTrades: async (req, res) => {
    try {
      const userId = req.userId;
      const { status, role, page = 1, limit = 10 } = req.query;
      
      // Calculate pagination
      const offset = (page - 1) * limit;
      
      // Build where conditions
      const whereConditions = {};
      
      if (status) {
        whereConditions.status = status;
      }
      
      // Filter by user role (proposer or receiver)
      if (role === 'proposer') {
        whereConditions.proposerId = userId;
      } else if (role === 'receiver') {
        whereConditions.receiverId = userId;
      } else {
        // Default: get all trades where user is either proposer or receiver
        whereConditions[Op.or] = [
          { proposerId: userId },
          { receiverId: userId }
        ];
      }
      
      // Get trades
      const { count, rows: trades } = await Trade.findAndCountAll({
        where: whereConditions,
        include: [
          {
            model: User,
            as: 'proposer',
            attributes: ['id', 'username', 'profilePicture', 'barterScore']
          },
          {
            model: User,
            as: 'receiver',
            attributes: ['id', 'username', 'profilePicture', 'barterScore']
          },
          {
            model: Listing,
            as: 'proposerListing'
          },
          {
            model: Listing,
            as: 'receiverListing'
          }
        ],
        limit: parseInt(limit),
        offset: offset,
        order: [['createdAt', 'DESC']]
      });
      
      return res.status(200).json({
        trades,
        totalPages: Math.ceil(count / limit),
        currentPage: parseInt(page),
        totalTrades: count
      });
    } catch (error) {
      console.error('Get user trades error:', error);
      return res.status(500).json({ message: 'Server error', error: error.message });
    }
  },
  
  // Get trade by ID
  getTradeById: async (req, res) => {
    try {
      const userId = req.userId;
      const { id } = req.params;
      
      const trade = await Trade.findByPk(id, {
        include: [
          {
            model: User,
            as: 'proposer',
            attributes: ['id', 'username', 'profilePicture', 'barterScore', 'isVerified']
          },
          {
            model: User,
            as: 'receiver',
            attributes: ['id', 'username', 'profilePicture', 'barterScore', 'isVerified']
          },
          {
            model: Listing,
            as: 'proposerListing'
          },
          {
            model: Listing,
            as: 'receiverListing'
          }
        ]
      });
      
      if (!trade) {
        return res.status(404).json({ message: 'Trade not found' });
      }
      
      // Check if user is part of the trade
      if (trade.proposerId !== userId && trade.receiverId !== userId) {
        return res.status(403).json({ message: 'Unauthorized: You are not part of this trade' });
      }
      
      return res.status(200).json({ trade });
    } catch (error) {
      console.error('Get trade error:', error);
      return res.status(500).json({ message: 'Server error', error: error.message });
    }
  },
  
  // Accept trade
  acceptTrade: async (req, res) => {
    const transaction = await sequelize.transaction();
    
    try {
      const userId = req.userId;
      const { id } = req.params;
      const { meetupLocation, meetupTime, isEscrow } = req.body;
      
      const trade = await Trade.findByPk(id, {
        include: [
          { model: Listing, as: 'proposerListing' },
          { model: Listing, as: 'receiverListing' }
        ],
        transaction
      });
      
      if (!trade) {
        await transaction.rollback();
        return res.status(404).json({ message: 'Trade not found' });
      }
      
      // Check if user is the receiver
      if (trade.receiverId !== userId) {
        await transaction.rollback();
        return res.status(403).json({ message: 'Unauthorized: Only the receiver can accept the trade' });
      }
      
      // Check if trade is in proposed status
      if (trade.status !== 'proposed') {
        await transaction.rollback();
        return res.status(400).json({ message: `Trade cannot be accepted because it is ${trade.status}` });
      }
      
      // Update trade status
      trade.status = 'accepted';
      trade.meetupLocation = meetupLocation;
      trade.meetupTime = meetupTime;
      trade.isEscrow = isEscrow || false;
      
      if (isEscrow) {
        // Set escrow release date (e.g., 7 days from now)
        const releaseDate = new Date();
        releaseDate.setDate(releaseDate.getDate() + 7);
        trade.escrowReleaseDate = releaseDate;
      }
      
      await trade.save({ transaction });
      
      // Mark listings as unavailable
      await Listing.update(
        { isAvailable: false },
        { 
          where: { 
            id: { 
              [Op.in]: [trade.proposerListingId, trade.receiverListingId] 
            } 
          },
          transaction 
        }
      );
      
      await transaction.commit();
      
      return res.status(200).json({
        message: 'Trade accepted successfully',
        trade
      });
    } catch (error) {
      await transaction.rollback();
      console.error('Accept trade error:', error);
      return res.status(500).json({ message: 'Server error', error: error.message });
    }
  },
  
  // Reject trade
  rejectTrade: async (req, res) => {
    try {
      const userId = req.userId;
      const { id } = req.params;
      const { reason } = req.body;
      
      const trade = await Trade.findByPk(id);
      
      if (!trade) {
        return res.status(404).json({ message: 'Trade not found' });
      }
      
      // Check if user is part of the trade
      if (trade.proposerId !== userId && trade.receiverId !== userId) {
        return res.status(403).json({ message: 'Unauthorized: You are not part of this trade' });
      }
      
      // Check if trade can be rejected
      if (trade.status !== 'proposed') {
        return res.status(400).json({ message: `Trade cannot be rejected because it is ${trade.status}` });
      }
      
      // Update trade status
      trade.status = 'rejected';
      trade.notes = trade.notes ? `${trade.notes}\nRejection reason: ${reason}` : `Rejection reason: ${reason}`;
      
      await trade.save();
      
      return res.status(200).json({
        message: 'Trade rejected successfully',
        trade
      });
    } catch (error) {
      console.error('Reject trade error:', error);
      return res.status(500).json({ message: 'Server error', error: error.message });
    }
  },
  
  // Complete trade
  completeTrade: async (req, res) => {
    const transaction = await sequelize.transaction();
    
    try {
      const userId = req.userId;
      const { id } = req.params;
      
      const trade = await Trade.findByPk(id, {
        include: [
          { 
            model: User, 
            as: 'proposer',
            attributes: ['id', 'username', 'barterScore', 'tradeCoins']
          },
          { 
            model: User, 
            as: 'receiver',
            attributes: ['id', 'username', 'barterScore', 'tradeCoins']
          },
          { model: Listing, as: 'proposerListing' },
          { model: Listing, as: 'receiverListing' }
        ],
        transaction
      });
      
      if (!trade) {
        await transaction.rollback();
        return res.status(404).json({ message: 'Trade not found' });
      }
      
      // Check if user is part of the trade
      if (trade.proposerId !== userId && trade.receiverId !== userId) {
        await transaction.rollback();
        return res.status(403).json({ message: 'Unauthorized: You are not part of this trade' });
      }
      
      // Check if trade is in accepted status
      if (trade.status !== 'accepted') {
        await transaction.rollback();
        return res.status(400).json({ message: `Trade cannot be completed because it is ${trade.status}` });
      }
      
      // Update trade status
      trade.status = 'completed';
      await trade.save({ transaction });
      
      // Update user barter scores
      const proposer = trade.proposer;
      const receiver = trade.receiver;
      
      // Increase barter score for both users
      proposer.barterScore = parseFloat((proposer.barterScore + 0.5).toFixed(2));
      receiver.barterScore = parseFloat((receiver.barterScore + 0.5).toFixed(2));
      
      // Handle trade coins if any
      if (trade.tradeCoinAmount > 0) {
        proposer.tradeCoins -= trade.tradeCoinAmount;
        receiver.tradeCoins += trade.tradeCoinAmount;
      }
      
      await proposer.save({ transaction });
      await receiver.save({ transaction });
      
      // Add badges if applicable
      // This would be more complex in a real app
      
      await transaction.commit();
      
      return res.status(200).json({
        message: 'Trade completed successfully',
        trade
      });
    } catch (error) {
      await transaction.rollback();
      console.error('Complete trade error:', error);
      return res.status(500).json({ message: 'Server error', error: error.message });
    }
  },
  
  // Find trade matches
  findTradeMatches: async (req, res) => {
    try {
      const userId = req.userId;
      const { listingId, category, maxDistance, minValue, maxValue } = req.query;
      
      // Get the user's listing
      const userListing = await Listing.findByPk(listingId);
      
      if (!userListing) {
        return res.status(404).json({ message: 'Listing not found' });
      }
      
      // Check if user owns the listing
      if (userListing.userId !== userId) {
        return res.status(403).json({ message: 'Unauthorized: You do not own this listing' });
      }
      
      // Build where conditions for potential matches
      const whereConditions = {
        userId: { [Op.ne]: userId }, // Not the user's own listings
        isAvailable: true
      };
      
      // Filter by category if provided
      if (category) {
        whereConditions.category = category;
      }
      
      // Filter by value range if provided
      if (minValue || maxValue) {
        whereConditions.estimatedValue = {};
        if (minValue) whereConditions.estimatedValue[Op.gte] = parseFloat(minValue);
        if (maxValue) whereConditions.estimatedValue[Op.lte] = parseFloat(maxValue);
      }
      
      // Get potential matches
      const potentialMatches = await Listing.findAll({
        where: whereConditions,
        include: [{
          model: User,
          as: 'owner',
          attributes: ['id', 'username', 'profilePicture', 'barterScore', 'isVerified']
        }],
        limit: 20
      });
      
      // In a real app, you would implement more sophisticated matching algorithms
      // For example, using location data to calculate distance between users
      // For now, we'll just return the potential matches
      
      return res.status(200).json({
        userListing,
        potentialMatches
      });
    } catch (error) {
      console.error('Find trade matches error:', error);
      return res.status(500).json({ message: 'Server error', error: error.message });
    }
  },
  
  // Propose multi-party trade
  proposeMultiPartyTrade: async (req, res) => {
    const transaction = await sequelize.transaction();
    
    try {
      const proposerId = req.userId;
      const { tradeChain } = req.body;
      
      // Validate trade chain
      if (!tradeChain || !Array.isArray(tradeChain) || tradeChain.length < 3) {
        await transaction.rollback();
        return res.status(400).json({ message: 'Invalid trade chain. Must include at least 3 participants' });
      }
      
      // Verify that the proposer is part of the chain
      const proposerInChain = tradeChain.some(node => node.userId === proposerId);
      if (!proposerInChain) {
        await transaction.rollback();
        return res.status(400).json({ message: 'Proposer must be part of the trade chain' });
      }
      
      // Verify that the chain forms a loop (last user gives to first user)
      if (tradeChain[0].receiverId !== tradeChain[tradeChain.length - 1].userId) {
        await transaction.rollback();
        return res.status(400).json({ message: 'Trade chain must form a complete loop' });
      }
      
      // Verify all listings exist and are available
      for (const node of tradeChain) {
        const listing = await Listing.findByPk(node.listingId, { transaction });
        
        if (!listing) {
          await transaction.rollback();
          return res.status(404).json({ message: `Listing ${node.listingId} not found` });
        }
        
        if (!listing.isAvailable) {
          await transaction.rollback();
          return res.status(400).json({ message: `Listing ${node.listingId} is not available` });
        }
        
        if (listing.userId !== node.userId) {
          await transaction.rollback();
          return res.status(403).json({ message: `User ${node.userId} does not own listing ${node.listingId}` });
        }
      }
      
      // Create the multi-party trade
      const newTrade = await Trade.create({
        proposerId,
        receiverId: null, // No single receiver in multi-party trade
        status: 'proposed',
        type: 'multi-party',
        tradeChain
      }, { transaction });
      
      await transaction.commit();
      
      return res.status(201).json({
        message: 'Multi-party trade proposed successfully',
        trade: newTrade
      });
    } catch (error) {
      await transaction.rollback();
      console.error('Propose multi-party trade error:', error);
      return res.status(500).json({ message: 'Server error', error: error.message });
    }
  }
};

module.exports = tradeController;