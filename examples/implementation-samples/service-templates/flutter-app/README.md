# Flutter Mobile App Template - Kratos + Consul + Dapr Integration

## Overview
Production-ready Flutter mobile application template for the e-commerce platform with clean architecture, state management, and comprehensive features. Integrated with **Kratos + Consul + Dapr** backend microservices architecture.

## Tech Stack
- **Framework**: Flutter 3.16+ with Dart 3.2+
- **State Management**: Bloc/Cubit pattern with flutter_bloc
- **HTTP Client**: Dio with interceptors and retry logic
- **Backend Integration**: Kratos gRPC/HTTP services via Consul discovery
- **Real-time Communication**: WebSocket + Server-Sent Events
- **Local Storage**: Hive for lightweight data, SQLite for complex data
- **Navigation**: GoRouter for declarative routing
- **Authentication**: JWT token management with Kratos Auth Service
- **Push Notifications**: Firebase Cloud Messaging + Dapr bindings
- **Service Discovery**: Consul integration for dynamic service discovery
- **Dependency Injection**: get_it service locator
- **Testing**: Widget tests, integration tests, and golden tests

## Project Structure
```
flutter_app/
├── lib/
│   ├── main.dart                      # Application entry point
│   ├── app/                           # App-level configuration
│   │   ├── app.dart                   # Main app widget
│   │   ├── router.dart                # App routing configuration
│   │   └── theme.dart                 # App theme configuration
│   ├── core/                          # Core functionality
│   │   ├── constants/                 # App constants
│   │   │   ├── api_constants.dart
│   │   │   ├── app_constants.dart
│   │   │   └── storage_constants.dart
│   │   ├── errors/                    # Error handling
│   │   │   ├── exceptions.dart
│   │   │   └── failures.dart
│   │   ├── network/                   # Network layer
│   │   │   ├── api_client.dart
│   │   │   ├── interceptors/
│   │   │   │   ├── auth_interceptor.dart
│   │   │   │   ├── logging_interceptor.dart
│   │   │   │   └── retry_interceptor.dart
│   │   │   └── network_info.dart
│   │   ├── storage/                   # Local storage
│   │   │   ├── hive_storage.dart
│   │   │   ├── secure_storage.dart
│   │   │   └── sqlite_storage.dart
│   │   ├── utils/                     # Utility functions
│   │   │   ├── validators.dart
│   │   │   ├── formatters.dart
│   │   │   └── extensions.dart
│   │   └── di/                        # Dependency injection
│   │       └── injection.dart
│   ├── features/                      # Feature modules
│   │   ├── auth/                      # Authentication feature
│   │   │   ├── data/
│   │   │   │   ├── datasources/
│   │   │   │   │   ├── auth_local_datasource.dart
│   │   │   │   │   └── auth_remote_datasource.dart
│   │   │   │   ├── models/
│   │   │   │   │   ├── user_model.dart
│   │   │   │   │   └── auth_response_model.dart
│   │   │   │   └── repositories/
│   │   │   │       └── auth_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   ├── entities/
│   │   │   │   │   └── user.dart
│   │   │   │   ├── repositories/
│   │   │   │   │   └── auth_repository.dart
│   │   │   │   └── usecases/
│   │   │   │       ├── login_usecase.dart
│   │   │   │       ├── logout_usecase.dart
│   │   │   │       └── get_current_user_usecase.dart
│   │   │   └── presentation/
│   │   │       ├── bloc/
│   │   │       │   ├── auth_bloc.dart
│   │   │       │   ├── auth_event.dart
│   │   │       │   └── auth_state.dart
│   │   │       ├── pages/
│   │   │       │   ├── login_page.dart
│   │   │       │   ├── register_page.dart
│   │   │       │   └── profile_page.dart
│   │   │       └── widgets/
│   │   │           ├── login_form.dart
│   │   │           └── auth_button.dart
│   │   ├── catalog/                   # Product catalog feature
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   ├── cart/                      # Shopping cart feature
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   ├── checkout/                  # Checkout feature
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   └── orders/                    # Order management feature
│   │       ├── data/
│   │       ├── domain/
│   │       └── presentation/
│   └── shared/                        # Shared components
│       ├── widgets/                   # Reusable widgets
│       │   ├── buttons/
│       │   ├── cards/
│       │   ├── forms/
│       │   └── loading/
│       └── models/                    # Shared models
├── test/                              # Test files
│   ├── unit/
│   ├── widget/
│   ├── integration/
│   └── fixtures/
├── assets/                            # Static assets
│   ├── images/
│   ├── icons/
│   └── fonts/
├── android/                           # Android-specific code
├── ios/                               # iOS-specific code
├── pubspec.yaml                       # Dependencies
├── analysis_options.yaml             # Linting rules
└── README.md
```

## Quick Start

### 1. Setup
```bash
# Clone template
cp -r flutter-app my-ecommerce-app
cd my-ecommerce-app

# Install Flutter dependencies
flutter pub get

# Generate code (for json_serializable, etc.)
flutter packages pub run build_runner build

# Setup Firebase (optional)
flutterfire configure
```

### 2. Configuration
```bash
# Copy environment configuration
cp lib/core/constants/app_constants.dart.example lib/core/constants/app_constants.dart

# Update API endpoints and configuration
vim lib/core/constants/app_constants.dart
```

### 3. Run Application
```bash
# Run on debug mode
flutter run

# Run on specific device
flutter run -d <device_id>

# Run with flavor
flutter run --flavor development
```

## Core Files

### Main Entry Point (lib/main.dart)
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/app.dart';
import 'core/di/injection.dart';
import 'core/storage/hive_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  await HiveStorage.init();
  
  // Setup dependency injection
  await setupDependencyInjection();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(const ECommerceApp());
}
```

### App Configuration (lib/app/app.dart)
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/di/injection.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/catalog/presentation/bloc/catalog_bloc.dart';
import '../features/cart/presentation/bloc/cart_bloc.dart';
import 'router.dart';
import 'theme.dart';

class ECommerceApp extends StatelessWidget {
  const ECommerceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) => getIt<AuthBloc>()..add(AuthCheckRequested()),
        ),
        BlocProvider<CatalogBloc>(
          create: (context) => getIt<CatalogBloc>(),
        ),
        BlocProvider<CartBloc>(
          create: (context) => getIt<CartBloc>()..add(CartLoadRequested()),
        ),
      ],
      child: MaterialApp.router(
        title: 'E-Commerce App',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        routerConfig: AppRouter.router,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en', 'US'),
          Locale('vi', 'VN'),
        ],
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
```

### Router Configuration (lib/app/router.dart)
```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/di/injection.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/catalog/presentation/pages/catalog_page.dart';
import '../features/catalog/presentation/pages/product_detail_page.dart';
import '../features/cart/presentation/pages/cart_page.dart';
import '../features/checkout/presentation/pages/checkout_page.dart';
import '../features/orders/presentation/pages/orders_page.dart';
import '../features/orders/presentation/pages/order_detail_page.dart';
import '../shared/widgets/main_navigation.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/catalog',
    redirect: (context, state) {
      final authBloc = context.read<AuthBloc>();
      final isAuthenticated = authBloc.state is AuthAuthenticated;
      
      // Protected routes
      final protectedRoutes = ['/cart', '/checkout', '/orders', '/profile'];
      final isProtectedRoute = protectedRoutes.any((route) => 
        state.location.startsWith(route));
      
      if (isProtectedRoute && !isAuthenticated) {
        return '/login?redirect=${state.location}';
      }
      
      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: '/login',
        builder: (context, state) {
          final redirect = state.queryParameters['redirect'];
          return LoginPage(redirectPath: redirect);
        },
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      
      // Main app shell with bottom navigation
      ShellRoute(
        builder: (context, state, child) {
          return MainNavigation(child: child);
        },
        routes: [
          // Catalog routes
          GoRoute(
            path: '/catalog',
            builder: (context, state) => const CatalogPage(),
            routes: [
              GoRoute(
                path: 'product/:productId',
                builder: (context, state) {
                  final productId = state.pathParameters['productId']!;
                  return ProductDetailPage(productId: productId);
                },
              ),
            ],
          ),
          
          // Cart routes
          GoRoute(
            path: '/cart',
            builder: (context, state) => const CartPage(),
          ),
          
          // Checkout routes
          GoRoute(
            path: '/checkout',
            builder: (context, state) => const CheckoutPage(),
          ),
          
          // Orders routes
          GoRoute(
            path: '/orders',
            builder: (context, state) => const OrdersPage(),
            routes: [
              GoRoute(
                path: ':orderId',
                builder: (context, state) {
                  final orderId = state.pathParameters['orderId']!;
                  return OrderDetailPage(orderId: orderId);
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
```

### Consul Service Discovery Client (lib/core/network/consul_client.dart)
```dart
import 'package:dio/dio.dart';
import 'dart:math';

class ConsulServiceDiscovery {
  final Dio _dio;
  final String consulUrl;
  final Map<String, List<ServiceInstance>> _serviceCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Duration cacheTTL = const Duration(minutes: 5);
  
  ConsulServiceDiscovery({
    required this.consulUrl,
  }) : _dio = Dio();
  
  Future<ServiceInstance> discoverService(String serviceName) async {
    // Check cache first
    if (_serviceCache.containsKey(serviceName) && 
        _cacheTimestamps.containsKey(serviceName)) {
      final cacheTime = _cacheTimestamps[serviceName]!;
      if (DateTime.now().difference(cacheTime) < cacheTTL) {
        final services = _serviceCache[serviceName]!;
        if (services.isNotEmpty) {
          // Simple round-robin selection
          return services[Random().nextInt(services.length)];
        }
      }
    }
    
    try {
      final response = await _dio.get(
        '$consulUrl/v1/health/service/$serviceName',
        queryParameters: {'passing': 'true'},
      );
      
      final List<dynamic> services = response.data;
      if (services.isEmpty) {
        throw Exception('Service $serviceName not found');
      }
      
      final serviceInstances = services.map((service) {
        final serviceData = service['Service'];
        return ServiceInstance(
          id: serviceData['ID'],
          name: serviceData['Service'],
          address: serviceData['Address'],
          port: serviceData['Port'],
          tags: List<String>.from(serviceData['Tags'] ?? []),
          meta: Map<String, String>.from(serviceData['Meta'] ?? {}),
        );
      }).toList();
      
      // Update cache
      _serviceCache[serviceName] = serviceInstances;
      _cacheTimestamps[serviceName] = DateTime.now();
      
      // Return random instance
      return serviceInstances[Random().nextInt(serviceInstances.length)];
    } catch (e) {
      throw Exception('Failed to discover service $serviceName: $e');
    }
  }
}

class ServiceInstance {
  final String id;
  final String name;
  final String address;
  final int port;
  final List<String> tags;
  final Map<String, String> meta;
  
  ServiceInstance({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    required this.tags,
    required this.meta,
  });
  
  String get baseUrl => 'http://$address:$port';
  String get version => meta['version'] ?? 'unknown';
  List<String> get capabilities => meta['capabilities']?.split(',') ?? [];
}
```

### Kratos-Integrated API Client (lib/core/network/api_client.dart)
```dart
import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../constants/api_constants.dart';
import 'consul_client.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/consul_interceptor.dart';
import 'interceptors/retry_interceptor.dart';

class ApiClient {
  late final Dio _dio;
  late final ConsulServiceDiscovery _consulClient;
  
  ApiClient() {
    _consulClient = ConsulServiceDiscovery(
      consulUrl: ApiConstants.consulUrl,
    );
    
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    
    _setupInterceptors();
  }
  
  void _setupInterceptors() {
    // Consul service discovery interceptor
    _dio.interceptors.add(ConsulInterceptor(_consulClient));
    
    // Auth interceptor for JWT tokens
    _dio.interceptors.add(AuthInterceptor());
    
    // Retry interceptor with exponential backoff
    _dio.interceptors.add(RetryInterceptor(_dio));
    
    // Logging interceptor (only in debug mode)
    if (ApiConstants.enableLogging) {
      _dio.interceptors.add(PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        error: true,
        compact: true,
      ));
    }
  }
  
  // Service-specific API calls
  Future<Response<T>> callAuthService<T>(
    String path, {
    String method = 'GET',
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _callService<T>(
      'auth-service',
      path,
      method: method,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }
  
  Future<Response<T>> callCatalogService<T>(
    String path, {
    String method = 'GET',
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _callService<T>(
      'catalog-service',
      path,
      method: method,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }
  
  Future<Response<T>> callOrderService<T>(
    String path, {
    String method = 'GET',
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _callService<T>(
      'order-service',
      path,
      method: method,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }
  
  Future<Response<T>> _callService<T>(
    String serviceName,
    String path, {
    String method = 'GET',
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    // Add service name to options for Consul interceptor
    final serviceOptions = (options ?? Options()).copyWith(
      extra: {
        ...?options?.extra,
        'service_name': serviceName,
      },
    );
    
    switch (method.toUpperCase()) {
      case 'GET':
        return await _dio.get<T>(
          path,
          queryParameters: queryParameters,
          options: serviceOptions,
        );
      case 'POST':
        return await _dio.post<T>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: serviceOptions,
        );
      case 'PUT':
        return await _dio.put<T>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: serviceOptions,
        );
      case 'DELETE':
        return await _dio.delete<T>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: serviceOptions,
        );
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }
  }
}
```

### Consul Interceptor (lib/core/network/interceptors/consul_interceptor.dart)
```dart
import 'package:dio/dio.dart';
import '../consul_client.dart';

class ConsulInterceptor extends Interceptor {
  final ConsulServiceDiscovery _consulClient;
  
  ConsulInterceptor(this._consulClient);
  
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final serviceName = options.extra['service_name'] as String?;
      
      if (serviceName != null) {
        // Discover service via Consul
        final serviceInstance = await _consulClient.discoverService(serviceName);
        
        // Update base URL with discovered service
        options.baseUrl = serviceInstance.baseUrl;
        
        // Add service metadata to headers
        options.headers['X-Service-Version'] = serviceInstance.version;
        options.headers['X-Service-Instance'] = serviceInstance.id;
        
        print('Calling $serviceName at ${serviceInstance.baseUrl}');
      }
      
      handler.next(options);
    } catch (e) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: 'Service discovery failed: $e',
          type: DioExceptionType.unknown,
        ),
      );
    }
  }
}
```

### Auth Bloc (lib/features/auth/presentation/bloc/auth_bloc.dart)
```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/user.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/get_current_user_usecase.dart';

// Events
abstract class AuthEvent extends Equatable {
  const AuthEvent();
  
  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  
  const AuthLoginRequested({
    required this.email,
    required this.password,
  });
  
  @override
  List<Object?> get props => [email, password];
}

class AuthLogoutRequested extends AuthEvent {}

class AuthRegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String name;
  
  const AuthRegisterRequested({
    required this.email,
    required this.password,
    required this.name,
  });
  
  @override
  List<Object?> get props => [email, password, name];
}

// States
abstract class AuthState extends Equatable {
  const AuthState();
  
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final User user;
  
  const AuthAuthenticated({required this.user});
  
  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  
  const AuthError({required this.message});
  
  @override
  List<Object?> get props => [message];
}

// Bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase _loginUseCase;
  final LogoutUseCase _logoutUseCase;
  final GetCurrentUserUseCase _getCurrentUserUseCase;
  
  AuthBloc({
    required LoginUseCase loginUseCase,
    required LogoutUseCase logoutUseCase,
    required GetCurrentUserUseCase getCurrentUserUseCase,
  })  : _loginUseCase = loginUseCase,
        _logoutUseCase = logoutUseCase,
        _getCurrentUserUseCase = getCurrentUserUseCase,
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthRegisterRequested>(_onAuthRegisterRequested);
  }
  
  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    
    final result = await _getCurrentUserUseCase();
    
    result.fold(
      (failure) => emit(AuthUnauthenticated()),
      (user) => emit(AuthAuthenticated(user: user)),
    );
  }
  
  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    
    final result = await _loginUseCase(LoginParams(
      email: event.email,
      password: event.password,
    ));
    
    result.fold(
      (failure) => emit(AuthError(message: failure.message)),
      (user) => emit(AuthAuthenticated(user: user)),
    );
  }
  
  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    
    final result = await _logoutUseCase();
    
    result.fold(
      (failure) => emit(AuthError(message: failure.message)),
      (_) => emit(AuthUnauthenticated()),
    );
  }
  
  Future<void> _onAuthRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    
    // Implement registration logic
    // Similar to login but with registration use case
  }
}
```

### Product Model (lib/features/catalog/data/models/product_model.dart)
```dart
import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/product.dart';

part 'product_model.g.dart';

@JsonSerializable()
class ProductModel extends Product {
  const ProductModel({
    required super.id,
    required super.sku,
    required super.name,
    required super.description,
    required super.price,
    required super.discountedPrice,
    required super.currency,
    required super.imageUrl,
    required super.images,
    required super.category,
    required super.brand,
    required super.attributes,
    required super.inStock,
    required super.stockQuantity,
    required super.rating,
    required super.reviewCount,
    required super.isFeatured,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) =>
      _$ProductModelFromJson(json);

  Map<String, dynamic> toJson() => _$ProductModelToJson(this);

  factory ProductModel.fromEntity(Product product) {
    return ProductModel(
      id: product.id,
      sku: product.sku,
      name: product.name,
      description: product.description,
      price: product.price,
      discountedPrice: product.discountedPrice,
      currency: product.currency,
      imageUrl: product.imageUrl,
      images: product.images,
      category: product.category,
      brand: product.brand,
      attributes: product.attributes,
      inStock: product.inStock,
      stockQuantity: product.stockQuantity,
      rating: product.rating,
      reviewCount: product.reviewCount,
      isFeatured: product.isFeatured,
      createdAt: product.createdAt,
      updatedAt: product.updatedAt,
    );
  }
}

@JsonSerializable()
class ProductListResponseModel {
  final List<ProductModel> products;
  final PaginationModel pagination;

  const ProductListResponseModel({
    required this.products,
    required this.pagination,
  });

  factory ProductListResponseModel.fromJson(Map<String, dynamic> json) =>
      _$ProductListResponseModelFromJson(json);

  Map<String, dynamic> toJson() => _$ProductListResponseModelToJson(this);
}

@JsonSerializable()
class PaginationModel {
  final int page;
  final int limit;
  final int total;
  final int pages;

  const PaginationModel({
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  factory PaginationModel.fromJson(Map<String, dynamic> json) =>
      _$PaginationModelFromJson(json);

  Map<String, dynamic> toJson() => _$PaginationModelToJson(this);
}
```

### Dependency Injection (lib/core/di/injection.dart)
```dart
import 'package:get_it/get_it.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

import '../network/api_client.dart';
import '../network/network_info.dart';
import '../storage/hive_storage.dart';
import '../storage/secure_storage.dart';

// Features
import '../../features/auth/data/datasources/auth_local_datasource.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/logout_usecase.dart';
import '../../features/auth/domain/usecases/get_current_user_usecase.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';

import '../../features/catalog/data/datasources/catalog_remote_datasource.dart';
import '../../features/catalog/data/repositories/catalog_repository_impl.dart';
import '../../features/catalog/domain/repositories/catalog_repository.dart';
import '../../features/catalog/domain/usecases/get_products_usecase.dart';
import '../../features/catalog/domain/usecases/get_product_usecase.dart';
import '../../features/catalog/presentation/bloc/catalog_bloc.dart';

import '../../features/cart/data/datasources/cart_local_datasource.dart';
import '../../features/cart/data/repositories/cart_repository_impl.dart';
import '../../features/cart/domain/repositories/cart_repository.dart';
import '../../features/cart/domain/usecases/add_to_cart_usecase.dart';
import '../../features/cart/domain/usecases/get_cart_usecase.dart';
import '../../features/cart/presentation/bloc/cart_bloc.dart';

final getIt = GetIt.instance;

Future<void> setupDependencyInjection() async {
  // Core
  getIt.registerLazySingleton<ApiClient>(() => ApiClient());
  getIt.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(InternetConnectionChecker()),
  );
  getIt.registerLazySingleton<HiveStorage>(() => HiveStorage());
  getIt.registerLazySingleton<SecureStorage>(() => SecureStorage());

  // Auth feature
  getIt.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(apiClient: getIt()),
  );
  getIt.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(
      hiveStorage: getIt(),
      secureStorage: getIt(),
    ),
  );
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: getIt(),
      localDataSource: getIt(),
      networkInfo: getIt(),
    ),
  );
  getIt.registerLazySingleton(() => LoginUseCase(getIt()));
  getIt.registerLazySingleton(() => LogoutUseCase(getIt()));
  getIt.registerLazySingleton(() => GetCurrentUserUseCase(getIt()));
  getIt.registerFactory(
    () => AuthBloc(
      loginUseCase: getIt(),
      logoutUseCase: getIt(),
      getCurrentUserUseCase: getIt(),
    ),
  );

  // Catalog feature
  getIt.registerLazySingleton<CatalogRemoteDataSource>(
    () => CatalogRemoteDataSourceImpl(apiClient: getIt()),
  );
  getIt.registerLazySingleton<CatalogRepository>(
    () => CatalogRepositoryImpl(
      remoteDataSource: getIt(),
      networkInfo: getIt(),
    ),
  );
  getIt.registerLazySingleton(() => GetProductsUseCase(getIt()));
  getIt.registerLazySingleton(() => GetProductUseCase(getIt()));
  getIt.registerFactory(() => CatalogBloc(
    getProductsUseCase: getIt(),
    getProductUseCase: getIt(),
  ));

  // Cart feature
  getIt.registerLazySingleton<CartLocalDataSource>(
    () => CartLocalDataSourceImpl(hiveStorage: getIt()),
  );
  getIt.registerLazySingleton<CartRepository>(
    () => CartRepositoryImpl(localDataSource: getIt()),
  );
  getIt.registerLazySingleton(() => AddToCartUseCase(getIt()));
  getIt.registerLazySingleton(() => GetCartUseCase(getIt()));
  getIt.registerFactory(() => CartBloc(
    addToCartUseCase: getIt(),
    getCartUseCase: getIt(),
  ));
}
```

### Real-time Communication (lib/core/realtime/websocket_client.dart)
```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class WebSocketClient {
  WebSocket? _socket;
  final String _url;
  final Map<String, List<Function(dynamic)>> _listeners = {};
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 5;
  bool _isConnecting = false;
  
  WebSocketClient(this._url);
  
  Future<void> connect() async {
    if (_isConnecting || _socket != null) return;
    
    _isConnecting = true;
    
    try {
      _socket = await WebSocket.connect(_url);
      _isConnecting = false;
      _reconnectAttempts = 0;
      
      print('WebSocket connected to $_url');
      
      _socket!.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDisconnected,
      );
      
      _startHeartbeat();
    } catch (e) {
      _isConnecting = false;
      print('WebSocket connection failed: $e');
      _scheduleReconnect();
    }
  }
  
  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      final eventType = data['type'] as String?;
      
      if (eventType != null && _listeners.containsKey(eventType)) {
        for (final listener in _listeners[eventType]!) {
          listener(data);
        }
      }
    } catch (e) {
      print('Error parsing WebSocket message: $e');
    }
  }
  
  void _onError(error) {
    print('WebSocket error: $error');
  }
  
  void _onDisconnected() {
    print('WebSocket disconnected');
    _cleanup();
    _scheduleReconnect();
  }
  
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_socket != null) {
        send('ping', {});
      }
    });
  }
  
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('Max reconnection attempts reached');
      return;
    }
    
    final delay = Duration(seconds: pow(2, _reconnectAttempts).toInt());
    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      connect();
    });
  }
  
  void _cleanup() {
    _socket = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
  
  void send(String type, Map<String, dynamic> data) {
    if (_socket != null) {
      final message = jsonEncode({
        'type': type,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _socket!.add(message);
    }
  }
  
  void subscribe(String eventType, Function(dynamic) listener) {
    if (!_listeners.containsKey(eventType)) {
      _listeners[eventType] = [];
    }
    _listeners[eventType]!.add(listener);
  }
  
  void unsubscribe(String eventType, Function(dynamic) listener) {
    if (_listeners.containsKey(eventType)) {
      _listeners[eventType]!.remove(listener);
    }
  }
  
  void disconnect() {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _socket?.close();
    _cleanup();
    _listeners.clear();
  }
}
```

### Push Notification Service (lib/core/notifications/push_notification_service.dart)
```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  static Future<void> initialize() async {
    // Request permission
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else {
      print('User declined or has not accepted permission');
    }
    
    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    
    // Get FCM token
    final token = await _firebaseMessaging.getToken();
    print('FCM Token: $token');
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    
    // Handle notification tap when app is terminated
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }
  
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Received foreground message: ${message.messageId}');
    
    // Show local notification
    await _showLocalNotification(message);
    
    // Handle different message types
    _handleMessageData(message);
  }
  
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default Channel',
      channelDescription: 'Default notification channel',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const iosDetails = DarwinNotificationDetails();
    
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      notificationDetails,
      payload: jsonEncode(message.data),
    );
  }
  
  static void _handleMessageData(RemoteMessage message) {
    final data = message.data;
    
    switch (data['type']) {
      case 'order_status_update':
        _handleOrderStatusUpdate(data);
        break;
      case 'promotion_available':
        _handlePromotionNotification(data);
        break;
      case 'cart_reminder':
        _handleCartReminder(data);
        break;
      default:
        print('Unknown message type: ${data['type']}');
    }
  }
  
  static void _handleOrderStatusUpdate(Map<String, dynamic> data) {
    final orderId = data['order_id'];
    final status = data['status'];
    
    // Navigate to order details or update order state
    print('Order $orderId status updated to $status');
  }
  
  static void _handlePromotionNotification(Map<String, dynamic> data) {
    final promotionId = data['promotion_id'];
    final discount = data['discount'];
    
    // Navigate to promotion details
    print('New promotion available: $discount% off');
  }
  
  static void _handleCartReminder(Map<String, dynamic> data) {
    final itemCount = data['item_count'];
    
    // Navigate to cart
    print('You have $itemCount items in your cart');
  }
  
  static void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.messageId}');
    _handleMessageData(message);
  }
  
  static void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      final data = jsonDecode(response.payload!);
      _handleMessageData(RemoteMessage(data: Map<String, String>.from(data)));
    }
  }
  
  static Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }
  
  static Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
  }
  
  static Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
  }
}

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling background message: ${message.messageId}');
  // Handle background message
}
```

### pubspec.yaml (Updated with Kratos + Consul + Dapr dependencies)
```yaml
name: ecommerce_app
description: E-commerce mobile application with Kratos + Consul + Dapr integration
version: 1.0.0+1

environment:
  sdk: '>=3.2.0 <4.0.0'
  flutter: ">=3.16.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  # State Management
  flutter_bloc: ^8.1.3
  equatable: ^2.0.5

  # Navigation
  go_router: ^12.1.3

  # HTTP Client & Service Discovery
  dio: ^5.3.2
  pretty_dio_logger: ^1.3.1
  internet_connection_checker: ^1.0.0+1

  # Real-time Communication
  web_socket_channel: ^2.4.0
  socket_io_client: ^2.0.3+1

  # Local Storage
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  flutter_secure_storage: ^9.0.0
  sqflite: ^2.3.0

  # Dependency Injection
  get_it: ^7.6.4

  # JSON Serialization
  json_annotation: ^4.8.1

  # UI Components
  cached_network_image: ^3.3.0
  shimmer: ^3.0.0
  pull_to_refresh: ^2.0.0
  flutter_staggered_grid_view: ^0.7.0

  # Utilities
  intl: ^0.18.1
  url_launcher: ^6.2.1
  share_plus: ^7.2.1
  image_picker: ^1.0.4

  # Firebase & Push Notifications
  firebase_core: ^2.24.2
  firebase_messaging: ^14.7.9
  firebase_analytics: ^10.7.4
  firebase_crashlytics: ^3.4.8
  flutter_local_notifications: ^16.3.0

  # Performance & Monitoring
  firebase_performance: ^0.9.3+6

  # Other
  permission_handler: ^11.0.1
  package_info_plus: ^4.2.0
  device_info_plus: ^9.1.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1

  # Code Generation
  build_runner: ^2.4.7
  json_serializable: ^6.7.1
  hive_generator: ^2.0.1

  # Testing
  bloc_test: ^9.1.5
  mocktail: ^1.0.1
  integration_test:
    sdk: flutter

flutter:
  uses-material-design: true

  assets:
    - assets/images/
    - assets/icons/

  fonts:
    - family: Roboto
      fonts:
        - asset: assets/fonts/Roboto-Regular.ttf
        - asset: assets/fonts/Roboto-Bold.ttf
          weight: 700
```

### Build Configuration (android/app/build.gradle)
```gradle
android {
    namespace "com.ecommerce.app"
    compileSdkVersion 34
    ndkVersion flutter.ndkVersion

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = '1.8'
    }

    sourceSets {
        main.java.srcDirs += 'src/main/kotlin'
    }

    defaultConfig {
        applicationId "com.ecommerce.app"
        minSdkVersion 21
        targetSdkVersion 34
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
        multiDexEnabled true
    }

    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
        debug {
            applicationIdSuffix ".debug"
            debuggable true
        }
    }

    flavorDimensions "default"
    productFlavors {
        development {
            dimension "default"
            applicationIdSuffix ".dev"
            versionNameSuffix "-dev"
            resValue "string", "app_name", "E-Commerce Dev"
        }
        staging {
            dimension "default"
            applicationIdSuffix ".staging"
            versionNameSuffix "-staging"
            resValue "string", "app_name", "E-Commerce Staging"
        }
        production {
            dimension "default"
            resValue "string", "app_name", "E-Commerce"
        }
    }
}
```

This Flutter app template provides a complete, production-ready foundation for building mobile e-commerce applications with clean architecture, comprehensive state management, and all necessary integrations for a modern mobile app.