const { Listing, User } = require('../models');
const { Op } = require('sequelize');
const admin = require('firebase-admin');

const listingController = {
  // Create a new listing
  createListing: async (req, res) => {
    try {
      const userId = req.userId;
      const { title, description, category, condition, estimatedValue, tradePreferences, location } = req.body;
      
      // Process uploaded images (store locally or use a different service)
      const images = [];
      if (req.files && req.files.length > 0) {
        // For now, we'll store file paths or use a different storage solution
        // This is a placeholder - implement your preferred storage solution
        for (const file of req.files) {
          const fileName = `${Date.now()}_${file.originalname}`;
          // Store file locally or use another cloud storage service
          // For demo purposes, we'll use a placeholder URL
          images.push(`/uploads/listings/${fileName}`);
        }
      }
      
      // Create listing
      const newListing = await Listing.create({
        title,
        description,
        category,
        condition,
        estimatedValue,
        tradePreferences,
        location,
        images,
        userId
      });
      
      return res.status(201).json({
        message: 'Listing created successfully',
        listing: newListing
      });
    } catch (error) {
      console.error('Create listing error:', error);
      return res.status(500).json({ message: 'Server error', error: error.message });
    }
  },
  
  // Get all listings with pagination and filters
  getAllListings: async (req, res) => {
    try {
      const { page = 1, limit = 10, category, condition, minValue, maxValue, search, location } = req.query;
      
      // Build filter conditions
      const whereConditions = {};
      
      if (category) whereConditions.category = category;
      if (condition) whereConditions.condition = condition;
      
      if (minValue || maxValue) {
        whereConditions.estimatedValue = {};
        if (minValue) whereConditions.estimatedValue[Op.gte] = parseFloat(minValue);
        if (maxValue) whereConditions.estimatedValue[Op.lte] = parseFloat(maxValue);
      }
      
      if (search) {
        whereConditions[Op.or] = [
          { title: { [Op.iLike]: `%${search}%` } },
          { description: { [Op.iLike]: `%${search}%` } }
        ];
      }
      
      if (location) {
        whereConditions.location = { [Op.iLike]: `%${location}%` };
      }
      
      // Only show available listings
      whereConditions.isAvailable = true;
      
      // Calculate pagination
      const offset = (page - 1) * limit;
      
      // Get listings
      const { count, rows: listings } = await Listing.findAndCountAll({
        where: whereConditions,
        include: [{
          model: User,
          as: 'owner',
          attributes: ['id', 'username', 'profilePicture', 'barterScore', 'isVerified']
        }],
        limit: parseInt(limit),
        offset: offset,
        order: [['createdAt', 'DESC']]
      });
      
      return res.status(200).json({
        listings,
        totalPages: Math.ceil(count / limit),
        currentPage: parseInt(page),
        totalListings: count
      });
    } catch (error) {
      console.error('Get all listings error:', error);
      return res.status(500).json({ message: 'Server error', error: error.message });
    }
  },
  
  // Get listing by ID
  getListingById: async (req, res) => {
    try {
      const { id } = req.params;
      
      const listing = await Listing.findByPk(id, {
        include: [{
          model: User,
          as: 'owner',
          attributes: ['id', 'username', 'profilePicture', 'barterScore', 'isVerified']
        }]
      });
      
      if (!listing) {
        return res.status(404).json({ message: 'Listing not found' });
      }
      
      // Increment view count
      listing.viewCount += 1;
      await listing.save();
      
      return res.status(200).json({ listing });
    } catch (error) {
      console.error('Get listing error:', error);
      return res.status(500).json({ message: 'Server error', error: error.message });
    }
  },
  
  // Update listing
  updateListing: async (req, res) => {
    try {
      const userId = req.userId;
      const { id } = req.params;
      const { title, description, category, condition, estimatedValue, tradePreferences, location, isAvailable } = req.body;
      
      const listing = await Listing.findByPk(id);
      
      if (!listing) {
        return res.status(404).json({ message: 'Listing not found' });
      }
      
      // Check if user owns the listing
      if (listing.userId !== userId) {
        return res.status(403).json({ message: 'Unauthorized: You do not own this listing' });
      }
      
      // Process new images if any
      if (req.files && req.files.length > 0) {
        const newImages = [];

        for (const file of req.files) {
          const fileName = `${Date.now()}_${file.originalname}`;
          // Store file locally or use another cloud storage service
          // For demo purposes, we'll use a placeholder URL
          newImages.push(`/uploads/listings/${fileName}`);
        }

        // Combine with existing images or replace them
        if (req.body.keepExistingImages === 'true') {
          listing.images = [...listing.images, ...newImages];
        } else {
          listing.images = newImages;
        }
      }
      
      // Update listing fields
      if (title) listing.title = title;
      if (description) listing.description = description;
      if (category) listing.category = category;
      if (condition) listing.condition = condition;
      if (estimatedValue) listing.estimatedValue = estimatedValue;
      if (tradePreferences) listing.tradePreferences = tradePreferences;
      if (location) listing.location = location;
      if (isAvailable !== undefined) listing.isAvailable = isAvailable;
      
      await listing.save();
      
      return res.status(200).json({
        message: 'Listing updated successfully',
        listing
      });
    } catch (error) {
      console.error('Update listing error:', error);
      return res.status(500).json({ message: 'Server error', error: error.message });
    }
  },
  
  // Delete listing
  deleteListing: async (req, res) => {
    try {
      const userId = req.userId;
      const { id } = req.params;
      
      const listing = await Listing.findByPk(id);
      
      if (!listing) {
        return res.status(404).json({ message: 'Listing not found' });
      }
      
      // Check if user owns the listing
      if (listing.userId !== userId) {
        return res.status(403).json({ message: 'Unauthorized: You do not own this listing' });
      }
      
      await listing.destroy();
      
      return res.status(200).json({ message: 'Listing deleted successfully' });
    } catch (error) {
      console.error('Delete listing error:', error);
      return res.status(500).json({ message: 'Server error', error: error.message });
    }
  },
  
  // Get listings by category
  getListingsByCategory: async (req, res) => {
    try {
      const { category } = req.params;
      const { page = 1, limit = 10 } = req.query;
      
      // Calculate pagination
      const offset = (page - 1) * limit;
      
      // Get listings
      const { count, rows: listings } = await Listing.findAndCountAll({
        where: { 
          category,
          isAvailable: true 
        },
        include: [{
          model: User,
          as: 'owner',
          attributes: ['id', 'username', 'profilePicture', 'barterScore', 'isVerified']
        }],
        limit: parseInt(limit),
        offset: offset,
        order: [['createdAt', 'DESC']]
      });
      
      return res.status(200).json({
        listings,
        totalPages: Math.ceil(count / limit),
        currentPage: parseInt(page),
        totalListings: count
      });
    } catch (error) {
      console.error('Get listings by category error:', error);
      return res.status(500).json({ message: 'Server error', error: error.message });
    }
  },
  
  // Get user listings
  getUserListings: async (req, res) => {
    try {
      const { userId } = req.params;
      const { page = 1, limit = 10, includeUnavailable = false } = req.query;
      
      // Calculate pagination
      const offset = (page - 1) * limit;
      
      // Build where conditions
      const whereConditions = { userId };
      
      if (!includeUnavailable || includeUnavailable === 'false') {
        whereConditions.isAvailable = true;
      }
      
      // Get listings
      const { count, rows: listings } = await Listing.findAndCountAll({
        where: whereConditions,
        limit: parseInt(limit),
        offset: offset,
        order: [['createdAt', 'DESC']]
      });
      
      return res.status(200).json({
        listings,
        totalPages: Math.ceil(count / limit),
        currentPage: parseInt(page),
        totalListings: count
      });
    } catch (error) {
      console.error('Get user listings error:', error);
      return res.status(500).json({ message: 'Server error', error: error.message });
    }
  }
};

module.exports = listingController;