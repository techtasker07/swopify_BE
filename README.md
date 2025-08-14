# Swopify Backend API

Backend API for Swopify, a modern barter application that allows users to exchange goods and services. Built with Dart and PostgreSQL.

## Tech Stack

- Dart
- Shelf (Dart HTTP server library)
- PostgreSQL Database
- Socket.IO for real-time messaging
- Docker for containerization

## Prerequisites

- Dart SDK (3.0.0 or higher)
- PostgreSQL database

## Environment Variables

Create a `.env` file in the root directory with the following variables:

```
# Server Configuration
PORT=3000
HOST=0.0.0.0

# Database Configuration (Live PostgreSQL)
DB_HOST=your-postgres-host
DB_PORT=5432
DB_NAME=your-database-name
DB_USER=your-database-user
DB_PASSWORD=your-database-password

# Application Configuration
ENVIRONMENT=production

# Live Server URL
API_BASE_URL=https://your-backend-url.com/api
```

## Database Setup

1. Create a Firebase project at [https://console.firebase.google.com/](https://console.firebase.google.com/)
2. Enable Authentication with Email/Password and Google providers
3. Generate a Firebase Admin SDK service account key
4. Save the service account key as `firebase-service-account.json` in the root directory

## Installation

```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Start production server
npm start
```

## Installation and Setup

### Development Setup

```bash
# Install dependencies
dart pub get

# Run the server
dart run bin/server.dart
```

### Docker Deployment

```bash
# Using Docker Compose (recommended)
docker-compose up -d

# Or manually with Docker
docker build -t swopify-backend .
docker run -p 3000:3000 -v $(pwd)/firebase-service-account.json:/app/firebase-service-account.json swopify-backend
```

## API Documentation

### Authentication

- `POST /api/auth/register` - Register a new user
- `POST /api/auth/login` - Login a user
- `POST /api/auth/reset-password` - Request password reset
- `POST /api/auth/verify-email` - Verify user email

### Listings

- `GET /api/listings` - Get all listings (with pagination and filters)
- `GET /api/listings/:id` - Get a specific listing
- `POST /api/listings` - Create a new listing
- `PUT /api/listings/:id` - Update a listing
- `DELETE /api/listings/:id` - Delete a listing
- `GET /api/listings/user/:userId` - Get listings by user
- `GET /api/listings/search` - Search listings

### Trades

- `GET /api/trades/user` - Get trades for the current user
- `GET /api/trades/:id` - Get a specific trade
- `POST /api/trades` - Create a new trade
- `PUT /api/trades/:id/accept` - Accept a trade
- `PUT /api/trades/:id/reject` - Reject a trade
- `PUT /api/trades/:id/cancel` - Cancel a trade
- `PUT /api/trades/:id/complete` - Complete a trade
- `PUT /api/trades/:id/items` - Add items to a trade

### Messages

- `GET /api/messages/conversations` - Get user conversations
- `GET /api/messages/conversations/:id` - Get a specific conversation
- `GET /api/messages/conversations/:id/messages` - Get messages in a conversation
- `POST /api/messages/conversations/:id/messages` - Send a message
- `PUT /api/messages/conversations/:id/read` - Mark conversation as read
- `POST /api/messages/conversations` - Create a new conversation

### Users

- `GET /api/users/me` - Get current user profile
- `GET /api/users/:id` - Get a user by ID
- `PUT /api/users/me` - Update current user profile
- `GET /api/users/:id/ratings` - Get user ratings
- `POST /api/users/:id/rate` - Rate a user

## Real-time Features

The backend uses Socket.IO for real-time communication:

- New messages notifications
- Trade status updates

## License

MIT