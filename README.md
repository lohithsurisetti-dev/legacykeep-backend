# 🏗️ LegacyKeep Backend - Microservices Architecture

## 🎯 Overview

This directory contains all the microservices for the LegacyKeep backend, each in its own independent git repository. This true microservices architecture allows for independent development, deployment, and scaling of each service.

## 🏢 Service Architecture

### **Core Services**

| Service | Repository | Purpose | Status |
|---------|------------|---------|--------|
| **API Gateway** | `api-gateway/` | Single entry point, routing, authentication | 🔄 Setup |
| **Auth Service** | `auth-service/` | User authentication and authorization | 🔄 Setup |
| **User Service** | `user-service/` | User profile and preference management | 🔄 Setup |
| **Family Service** | `family-service/` | Family circle and relationship management | 🔄 Setup |
| **Story Service** | `story-service/` | Story creation and content management | 🔄 Setup |
| **Media Service** | `media-service/` | File upload and media processing | 🔄 Setup |
| **Chat Service** | `chat-service/` | Real-time family communication | 🔄 Setup |
| **Notification Service** | `notification-service/` | Push notifications and alerts | 🔄 Setup |

### **Shared Components**

| Component | Repository | Purpose | Status |
|-----------|------------|---------|--------|
| **Shared Library** | `shared-lib/` | Common DTOs, utilities, configurations | 🔄 Setup |
| **Docker Configs** | `docker/` | Containerization and deployment | 🔄 Setup |
| **Documentation** | `docs/` | API docs and service documentation | 🔄 Setup |

## 🚀 Quick Start

### **Prerequisites**
- Java 17+
- Maven 3.8+
- Docker & Docker Compose
- PostgreSQL 15+
- MongoDB (for chat service)
- Redis (for caching)

### **Development Setup**

1. **Clone all repositories:**
```bash
# Each service is in its own directory with its own git repo
cd api-gateway && git clone <api-gateway-repo>
cd auth-service && git clone <auth-service-repo>
cd user-service && git clone <user-service-repo>
# ... repeat for all services
```

2. **Start local development environment:**
```bash
cd docker
docker-compose up -d
```

3. **Run services individually:**
```bash
# Each service can be run independently
cd auth-service && mvn spring-boot:run
cd user-service && mvn spring-boot:run
# ... etc
```

## 🔗 Service Communication

### **Synchronous Communication**
- **HTTP REST APIs** - Direct service-to-service calls
- **API Gateway** - Centralized routing and load balancing
- **Service Discovery** - Eureka for service registration

### **Asynchronous Communication** (Future)
- **Apache Kafka** - Event streaming platform
- **Event Sourcing** - Complete audit trail of all events

## 🗄️ Database Architecture

Each service has its own dedicated database:

| Service | Database | Purpose |
|---------|----------|---------|
| Auth Service | `auth_db` (PostgreSQL) | Users, roles, permissions |
| User Service | `user_db` (PostgreSQL) | User profiles, preferences |
| Family Service | `family_db` (PostgreSQL) | Family circles, relationships |
| Story Service | `story_db` (PostgreSQL) | Stories, content, metadata |
| Media Service | `media_db` (PostgreSQL) | Media files, processing status |
| Chat Service | `chat_db` (MongoDB) | Chat messages, rooms, sessions |
| Notification Service | `notification_db` (PostgreSQL) | Notifications, templates |

## 🔐 Security

- **JWT Tokens** - Stateless authentication
- **OAuth 2.0** - Social login integration
- **Role-Based Access Control** - Fine-grained permissions
- **API Gateway Security** - Centralized security enforcement

## 🚀 Deployment

### **Individual Service Deployment**
Each service can be deployed independently:
```bash
# Deploy auth service
cd auth-service
docker build -t legacykeep-auth-service .
docker push <registry>/legacykeep-auth-service

# Deploy user service
cd user-service
docker build -t legacykeep-user-service .
docker push <registry>/legacykeep-user-service
```

## 📊 Monitoring & Observability

- **Spring Boot Actuator** - Health checks and metrics
- **Prometheus + Grafana** - Metrics collection and visualization
- **ELK Stack** - Centralized logging
- **Distributed Tracing** - Request flow across services

## 🔄 Development Workflow

### **Independent Development**
- Each service can be developed independently
- Different teams can work on different services
- Services can use different technologies if needed
- Independent versioning and release cycles

### **Integration Testing**
- Cross-service integration tests
- End-to-end testing with all services
- API contract testing
- Performance testing

## 📝 Documentation

- **API Documentation** - Swagger/OpenAPI for each service
- **Service Documentation** - Individual README files
- **Architecture Documentation** - System design and patterns
- **Deployment Guides** - Service-specific deployment instructions

## 🤝 Contributing

Each service follows its own contribution guidelines:
- Independent code review processes
- Service-specific testing requirements
- Individual deployment pipelines
- Separate issue tracking

---

## 📋 Service Status

| Service | Development | Testing | Production |
|---------|-------------|---------|------------|
| API Gateway | 🔄 Setup | ⚪ Not Started | ⚪ Not Started |
| Auth Service | 🔄 Setup | ⚪ Not Started | ⚪ Not Started |
| User Service | 🔄 Setup | ⚪ Not Started | ⚪ Not Started |
| Family Service | 🔄 Setup | ⚪ Not Started | ⚪ Not Started |
| Story Service | 🔄 Setup | ⚪ Not Started | ⚪ Not Started |
| Media Service | 🔄 Setup | ⚪ Not Started | ⚪ Not Started |
| Chat Service | 🔄 Setup | ⚪ Not Started | ⚪ Not Started |
| Notification Service | 🔄 Setup | ⚪ Not Started | ⚪ Not Started |

---

*This multi-repo architecture ensures true microservices independence while maintaining the ability to develop all services in a single IDE instance.*
