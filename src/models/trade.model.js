const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');
const User = require('./user.model');
const Listing = require('./listing.model');

const Trade = sequelize.define('Trade', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true
  },
  status: {
    type: DataTypes.ENUM('proposed', 'accepted', 'rejected', 'completed', 'cancelled'),
    defaultValue: 'proposed'
  },
  type: {
    type: DataTypes.ENUM('direct', 'multi-party'),
    defaultValue: 'direct'
  },
  tradeChain: {
    type: DataTypes.JSONB,
    allowNull: true,
    comment: 'For multi-party trades'
  },
  tradeCoinAmount: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
    comment: 'Optional virtual currency amount'
  },
  meetupLocation: {
    type: DataTypes.STRING,
    allowNull: true
  },
  meetupTime: {
    type: DataTypes.DATE,
    allowNull: true
  },
  isEscrow: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  escrowReleaseDate: {
    type: DataTypes.DATE,
    allowNull: true
  },
  notes: {
    type: DataTypes.TEXT,
    allowNull: true
  }
}, {
  timestamps: true
});

// Associations
Trade.belongsTo(User, { foreignKey: 'proposerId', as: 'proposer' });
Trade.belongsTo(User, { foreignKey: 'receiverId', as: 'receiver' });
Trade.belongsTo(Listing, { foreignKey: 'proposerListingId', as: 'proposerListing' });
Trade.belongsTo(Listing, { foreignKey: 'receiverListingId', as: 'receiverListing' });

module.exports = Trade;