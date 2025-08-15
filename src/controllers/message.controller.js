const { Conversation, Message, User } = require('../models');
const { Op } = require('sequelize');
const admin = require('firebase-admin');

const messageController = {
  // Send a message
  sendMessage: async (req, res) => {
    try {
      const senderId = req.userId;
      const { receiverId, content, conversationId } = req.body;
      
      let conversation;
      
      // If conversationId is provided, use it
      if (conversationId) {
        conversation = await Conversation.findByPk(conversationId);
        
        if (!conversation) {
          return res.status(404).json({ message: 'Conversation not found' });
        }
        
        // Check if user is part of the conversation
        if (conversation.user1Id !== senderId && conversation.user2Id !== senderId) {
          return res.status(403).json({ message: 'Unauthorized: You are not part of this conversation' });
        }
      } else if (receiverId) {
        // Find existing conversation or create new one
        conversation = await Conversation.findOne({
          where: {
            [Op.or]: [
              { user1Id: senderId, user2Id: receiverId },
              { user1Id: receiverId, user2Id: senderId }
            ]
          }
        });
        
        if (!conversation) {
          // Create new conversation
          conversation = await Conversation.create({
            user1Id: senderId,
            user2Id: receiverId
          });
        }
      } else {
        return res.status(400).json({ message: 'Either conversationId or receiverId is required' });
      }
      
      // Process media if any
      let mediaUrl = null;
      let mediaType = null;

      if (req.file) {
        // Store file locally or use another cloud storage service
        const fileName = `${Date.now()}_${req.file.originalname}`;
        // For demo purposes, we'll use a placeholder URL
        mediaUrl = `/uploads/messages/${fileName}`;
        mediaType = req.file.mimetype.startsWith('image/') ? 'image' : 'video';
      }
      
      // Create message
      const newMessage = await Message.create({
        conversationId: conversation.id,
        senderId,
        content,
        mediaUrl,
        mediaType,
        isRead: false
      });
      
      // Get sender info
      const sender = await User.findByPk(senderId, {
        attributes: ['id', 'username', 'profilePicture']
      });
      
      // Combine message with sender info
      const messageWithSender = {
        ...newMessage.toJSON(),
        sender
      };
      
      return res.status(201).json({
        message: 'Message sent successfully',
        data: messageWithSender
      });
    } catch (error) {
      console.error('Send message error:', error);
      return res.status(500).json({ message: 'Server error', error: error.message });
    }
  },
  
  // Get user conversations
  getUserConversations: async (req, res) => {
    try {
      const userId = req.userId;
      
      // Find all conversations where user is either user1 or user2
      const conversations = await Conversation.findAll({
        where: {
          [Op.or]: [
            { user1Id: userId },
            { user2Id: userId }
          ]
        },
        include: [
          {
            model: User,
            as: 'user1',
            attributes: ['id', 'username', 'profilePicture']
          },
          {
            model: User,
            as: 'user2',
            attributes: ['id', 'username', 'profilePicture']
          },
          {
            model: Message,
            limit: 1,
            order: [['createdAt', 'DESC']],
            include: [{
              model: User,
              as: 'sender',
              attributes: ['id', 'username']
            }]
          }
        ],
        order: [['updatedAt', 'DESC']]
      });
      
      // Get unread message count for each conversation
      const conversationsWithUnreadCount = await Promise.all(conversations.map(async (conversation) => {
        const unreadCount = await Message.count({
          where: {
            conversationId: conversation.id,
            senderId: { [Op.ne]: userId },
            isRead: false
          }
        });
        
        return {
          ...conversation.toJSON(),
          unreadCount
        };
      }));
      
      return res.status(200).json({ conversations: conversationsWithUnreadCount });
    } catch (error) {
      console.error('Get user conversations error:', error);
      return res.status(500).json({ message: 'Server error', error: error.message });
    }
  },
  
  // Get conversation messages
  getConversationMessages: async (req, res) => {
    try {
      const userId = req.userId;
      const { conversationId } = req.params;
      const { page = 1, limit = 20 } = req.query;
      
      // Find conversation
      const conversation = await Conversation.findByPk(conversationId);
      
      if (!conversation) {
        return res.status(404).json({ message: 'Conversation not found' });
      }
      
      // Check if user is part of the conversation
      if (conversation.user1Id !== userId && conversation.user2Id !== userId) {
        return res.status(403).json({ message: 'Unauthorized: You are not part of this conversation' });
      }
      
      // Calculate pagination
      const offset = (page - 1) * limit;
      
      // Get messages
      const { count, rows: messages } = await Message.findAndCountAll({
        where: { conversationId },
        include: [{
          model: User,
          as: 'sender',
          attributes: ['id', 'username', 'profilePicture']
        }],
        limit: parseInt(limit),
        offset: offset,
        order: [['createdAt', 'DESC']]
      });
      
      // Mark messages as read
      await Message.update(
        { isRead: true },
        {
          where: {
            conversationId,
            senderId: { [Op.ne]: userId },
            isRead: false
          }
        }
      );
      
      return res.status(200).json({
        messages,
        totalPages: Math.ceil(count / limit),
        currentPage: parseInt(page),
        totalMessages: count
      });
    } catch (error) {
      console.error('Get conversation messages error:', error);
      return res.status(500).json({ message: 'Server error', error: error.message });
    }
  },
  
  // Mark message as read
  markMessageAsRead: async (req, res) => {
    try {
      const userId = req.userId;
      const { messageId } = req.params;
      
      // Find message
      const message = await Message.findByPk(messageId, {
        include: [{ model: Conversation }]
      });
      
      if (!message) {
        return res.status(404).json({ message: 'Message not found' });
      }
      
      // Check if user is part of the conversation
      const conversation = message.Conversation;
      if (conversation.user1Id !== userId && conversation.user2Id !== userId) {
        return res.status(403).json({ message: 'Unauthorized: You are not part of this conversation' });
      }
      
      // Check if message is already read
      if (message.isRead) {
        return res.status(200).json({ message: 'Message is already marked as read' });
      }
      
      // Mark message as read
      message.isRead = true;
      await message.save();
      
      return res.status(200).json({ message: 'Message marked as read' });
    } catch (error) {
      console.error('Mark message as read error:', error);
      return res.status(500).json({ message: 'Server error', error: error.message });
    }
  }
};

module.exports = messageController;