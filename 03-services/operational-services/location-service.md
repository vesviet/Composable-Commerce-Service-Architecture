# Location Service

## Overview
The Location Service manages hierarchical geographic location data (countries, states, cities, districts, and wards). It provides APIs for retrieving location details, searching, and managing the location tree.

## Architecture
The service follows Clean Architecture and integrates with:
- **PostgreSQL**: Primary data storage.
- **Redis**: Caching for location details and trees.
- **Dapr**: For event-driven updates (via Outbox pattern).

## Key Features
- **Hierarchical Data**: Supports multiple levels of geographic granularity.
- **Tree Retrieval**: Efficiently fetch full or partial location trees.
- **Path Search**: Find the complete path from a leaf location back to the root (country).
- **Caching**: High-performance read operations using Redis.
- **Multilingual Support**: Supports names in various languages (e.g., English, Vietnamese).

## API Endpoints
- `GET /api/v1/location/{id}`: Get location by ID.
- `GET /api/v1/location`: List locations with filters.
- `GET /api/v1/location/tree`: Get location tree.
- `GET /api/v1/location/{id}/path`: Get path to root.
- `GET /api/v1/location/search`: Search by name or code.

## Configuration
Ports:
- HTTP: `8007`
- gRPC: `9007`

Environment Variables:
- `DATABASE_URL`: PostgreSQL connection string.
- `REDIS_URL`: Redis connection string.
