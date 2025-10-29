# Flutter Mobile App Template

## Overview
Production-ready Flutter mobile application template for the e-commerce platform with clean architecture, state management, and comprehensive features.

## Tech Stack
- **Framework**: Flutter 3.16+ with Dart 3.2+
- **State Management**: Bloc/Cubit pattern with flutter_bloc
- **HTTP Client**: Dio with interceptors and retry logic
- **Local Storage**: Hive for lightweight data, SQLite for complex data
- **Navigation**: GoRouter for declarative routing
- **Authentication**: JWT token management with secure storage
- **Push Notifications**: Firebase Cloud Messaging
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

### API Client (lib/core/network/api_client.dart)
```dart
import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../constants/api_constants.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/retry_interceptor.dart';

class ApiClient {
  late final Dio _dio;
  
  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
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
    // Auth interceptor
    _dio.interceptors.add(AuthInterceptor());
    
    // Retry interceptor
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
  
  // GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return await _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
  
  // POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return await _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
  
  // PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return await _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
  
  // DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return await _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
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

### pubspec.yaml
```yaml
name: ecommerce_app
description: E-commerce mobile application built with Flutter
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

  # HTTP Client
  dio: ^5.3.2
  pretty_dio_logger: ^1.3.1
  internet_connection_checker: ^1.0.0+1

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

  # Firebase
  firebase_core: ^2.24.2
  firebase_messaging: ^14.7.9
  firebase_analytics: ^10.7.4
  firebase_crashlytics: ^3.4.8

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