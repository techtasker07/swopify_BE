const { Rating, User, Trade } = require('../models');
const { Op } = require('sequelize');
const { sequelize } = require('../config/database');

const ratingController = {
  // Rate a user
  rateUser: async (req, res) => {
    const transaction = await sequelize.transaction();
    
    try {
      const raterId = req.userId;
      const { userId: ratedUserId } = req.params;
      const { score, comment, tradeId } = req.body;
      
      // Validate score
      if (score < 1 || score > 5) {
        await transaction.rollback();
        return res.status(400).json({ message: 'Score must be between 1 and 5' });
      }
      
      // Check if user is rating themselves
      if (raterId === ratedUserId) {
        await transaction.rollback();
        return res.status(400).json({ message: 'You cannot rate yourself' });
      }
      
      // If tradeId is provided, verify that both users were part of the trade
      if (tradeId) {
        const trade = await Trade.findByPk(tradeId, { transaction });
        
        if (!trade) {
          await transaction.rollback();
          return res.status(404).json({ message: 'Trade not found' });
        }
        
        // Check if both users were part of the trade
        const userInTrade = trade.proposerId === ratedUserId || trade.receiverId === ratedUserId;
        const raterInTrade = trade.proposerId === raterId || trade.receiverId === raterId;
        
        if (!userInTrade || !raterInTrade) {
          await transaction.rollback();
          return res.status(403).json({ message: 'Both users must be part of the trade' });
        }
        
        // Check if trade is completed
        if (trade.status !== 'completed') {
          await transaction.rollback();
          return res.status(400).json({ message: 'Trade must be completed before rating' });
        }
        
        // Check if user has already rated for this trade
        const existingRating = await Rating.findOne({
          where: {
            raterId,
            ratedUserId,
            tradeId
          },
          transaction
        });
        
        if (existingRating) {
          await transaction.rollback();
          return res.status(400).json({ message: 'You have already rated this user for this trade' });
        }
      }
      
      // Create rating
      const newRating = await Rating.create({
        raterId,
        ratedUserId,
        score,
        comment,
        tradeId
      }, { transaction });
      
      // Update user's barter score
      const ratedUser = await User.findByPk(ratedUserId, { transaction });
      
      if (!ratedUser) {
        await transaction.rollback();
        return res.status(404).json({ message: 'User not found' });
      }
      
      // Calculate new barter score (average of all ratings)
      const ratings = await Rating.findAll({
        where: { ratedUserId },
        attributes: ['score'],
        transaction
      });
      
      const totalScore = ratings.reduce((sum, rating) => sum + rating.score, 0);
      const averageScore = totalScore / ratings.length;
      
      ratedUser.barterScore = parseFloat(averageScore.toFixed(2));
      await ratedUser.save({ transaction });
      
      // Add badges if applicable
      if (ratings.length >= 10 && !ratedUser.badges.includes('Experienced Trader')) {
        ratedUser.badges = [...ratedUser.badges, 'Experienced Trader'];
        await ratedUser.save({ transaction });
      }
      
      if (ratedUser.barterScore >= 4.5 && !ratedUser.badges.includes('Top Rated')) {
        ratedUser.badges = [...ratedUser.badges, 'Top Rated'];
        await ratedUser.save({ transaction });
      }
      
      await transaction.commit();
      
      return res.status(201).json({
        message: 'Rating submitted successfully',
        rating: newRating
      });
    } catch (error) {
      await transaction.rollback();
      console.error('Rate user error:', error);
      return res.status(500).json({ message: 'Server error', error: error.message });
    }
  },
  
  // Get user ratings
  getUserRatings: async (req, res) => {
    try {
      const { userId } = req.params;
      const { page = 1, limit = 10 } = req.query;
      
      // Calculate pagination
      const offset = (page - 1) * limit;
      
      // Get ratings
      const { count, rows: ratings } = await Rating.findAndCountAll({
        where: { ratedUserId: userId },
        include: [{
          model: User,
          as: 'rater',
          attributes: ['id', 'username', 'profilePicture']
        }],
        limit: parseInt(limit),
        offset: offset,
        order: [['createdAt', 'DESC']]
      });
      
      return res.status(200).json({
        ratings,
        totalPages: Math.ceil(count / limit),
        currentPage: parseInt(page),
        totalRatings: count
      });
    } catch (error) {
      console.error('Get user ratings error:', error);
      return res.status(500).json({ message: 'Server error', error: error.message });
    }
  },
  
  // Get user rating stats
  getUserRatingStats: async (req, res) => {
    try {
      const { userId } = req.params;
      
      // Check if user exists
      const user = await User.findByPk(userId);
      
      if (!user) {
        return res.status(404).json({ message: 'User not found' });
      }
      
      // Get rating stats
      const totalRatings = await Rating.count({ where: { ratedUserId: userId } });
      
      // Get rating distribution
      const ratingDistribution = await Rating.findAll({
        where: { ratedUserId: userId },
        attributes: [
          'score',
          [sequelize.fn('COUNT', sequelize.col('score')), 'count']
        ],
        group: ['score'],
        order: [['score', 'DESC']]
      });
      
      // Format distribution
      const distribution = {};
      ratingDistribution.forEach(rating => {
        distribution[rating.score] = parseInt(rating.getDataValue('count'));
      });
      
      // Fill in missing scores with 0
      for (let i = 1; i <= 5; i++) {
        if (!distribution[i]) {
          distribution[i] = 0;
        }
      }
      
      return res.status(200).json({
        userId,
        barterScore: user.barterScore,
        totalRatings,
        distribution
      });
    } catch (error) {
      console.error('Get user rating stats error:', error);
      return res.status(500).json({ message: 'Server error', error: error.message });
    }
  }
};

module.exports = ratingController;