const admin = require('firebase-admin');
const { User, Rating } = require('../models');
const { sequelize } = require('../config/database');

const userController = {
  // Register a new user
  register: async (req, res) => {
    const { uid, email, username, profilePicture } = req.body;
    
    try {
      // Check if user already exists
      const existingUser = await User.findOne({ where: { id: uid } });
      
      if (existingUser) {
        return res.status(400).json({ message: 'User already exists' });
      }
      
      // Create new user
      const newUser = await User.create({
        id: uid,
        email,
        username,
        profilePicture,
        barterScore: 0,
        isVerified: false,
        tradeCoins: 50 // Starting trade coins
      });
      
      return res.status(201).json({
        message: 'User registered successfully',
        user: newUser
      });
    } catch (error) {
      console.error('Registration error:', error);
      return res.status(500).json({ message: 'Server error', error: error.message });
    }
  },
  
  // Login user (verify Firebase token)
  login: async (req, res) => {
    try {
      const { uid } = req.body;
      
      // Find user in database
      const user = await User.findByPk(uid);
      
      if (!user) {
        return res.status(404).json({ message: 'User not found' });
      }
      
      return res.status(200).json({
        message: 'Login successful',
        user
      });
    } catch (error) {
      console.error('Login error:', error);
      return res.status(500).json({ message: 'Server error', error: error.message });
    }
  },
  
  // Get user profile
  getProfile: async (req, res) => {
    try {
      const userId = req.userId;
      
      const user = await User.findByPk(userId);
      
      if (!user) {
        return res.status(404).json({ message: 'User not found' });
      }
      
      return res.status(200).json({ user });
    } catch (error) {
      console.error('Get profile error:', error);
      return res.status(500).json({ message: 'Server error', error: error.message });
    }
  },
  
  // Update user profile
  updateProfile: async (req, res) => {
    try {
      const userId = req.userId;
      const { username, bio, location, profilePicture, tradePreferences } = req.body;
      
      const user = await User.findByPk(userId);
      
      if (!user) {
        return res.status(404).json({ message: 'User not found' });
      }
      
      // Update user fields
      if (username) user.username = username;
      if (bio) user.bio = bio;
      if (location) user.location = location;
      if (profilePicture) user.profilePicture = profilePicture;
      if (tradePreferences) user.tradePreferences = tradePreferences;
      
      await user.save();
      
      return res.status(200).json({
        message: 'Profile updated successfully',
        user
      });
    } catch (error) {
      console.error('Update profile error:', error);
      return res.status(500).json({ message: 'Server error', error: error.message });
    }
  },
  
  // Verify user (KYC)
  verifyUser: async (req, res) => {
    try {
      const userId = req.userId;
      const { verificationDocuments } = req.body;
      
      const user = await User.findByPk(userId);
      
      if (!user) {
        return res.status(404).json({ message: 'User not found' });
      }
      
      // In a real app, you would process verification documents here
      // For demo purposes, we'll just mark the user as verified
      user.isVerified = true;
      
      // Add a verified badge
      if (!user.badges.includes('Verified User')) {
        user.badges = [...user.badges, 'Verified User'];
      }
      
      await user.save();
      
      return res.status(200).json({
        message: 'User verified successfully',
        user
      });
    } catch (error) {
      console.error('Verify user error:', error);
      return res.status(500).json({ message: 'Server error', error: error.message });
    }
  },
  
  // Get user by ID
  getUserById: async (req, res) => {
    try {
      const { id } = req.params;
      
      const user = await User.findByPk(id, {
        attributes: { exclude: ['email'] } // Don't expose email for privacy
      });
      
      if (!user) {
        return res.status(404).json({ message: 'User not found' });
      }
      
      return res.status(200).json({ user });
    } catch (error) {
      console.error('Get user error:', error);
      return res.status(500).json({ message: 'Server error', error: error.message });
    }
  },
  
  // Get user ratings
  getUserRatings: async (req, res) => {
    try {
      const { id } = req.params;
      
      const ratings = await Rating.findAll({
        where: { ratedUserId: id },
        include: [{
          model: User,
          as: 'rater',
          attributes: ['id', 'username', 'profilePicture']
        }]
      });
      
      return res.status(200).json({ ratings });
    } catch (error) {
      console.error('Get user ratings error:', error);
      return res.status(500).json({ message: 'Server error', error: error.message });
    }
  }
};

module.exports = userController;