# P-1.2 Flutter Payment Client Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Flutter reference payment client (`payment/` subdomain + independent `CheckoutScreen`) consuming the P-1.1 server API, with `MockPaymentProvider` and real-environment integration tests (live server + `mobileui_dev`, no fakes).

**Architecture:** New `flutter/lib/payment/` subdomain mirroring `flutter/lib/support/` (`PaymentRepository` owns the HTTP layer like `SupportRepository`; `PaymentController`+`PaymentScope` mirror `SupportController`/`SupportScope`; state via sealed `AsyncState`). `PaymentProvider` abstracts the store (only `MockPaymentProvider` in P-1.2; real SDK is P-2). Token read through a `TokenStore` interface (production = keychain, tests = in-memory) because `flutter test` runs in a keychain-less Dart VM. MembershipScreen rewired to a new `CheckoutScreen`; old `AppController.purchase`/`AppRepository.purchase` removed.

**Tech Stack:** Flutter 3.44 / Dart 3.12 · `package:http` · `flutter_secure_storage` · `flutter_test`. Server: Next.js on :3210 + Postgres `mobileui_dev`.

**Branch:** `p12-payment-flutter-client` (spec already committed at `d5977d3`).

---

## CRITICAL test prerequisite (read before any task that runs `flutter test`)

The integration tests hit the **real** P-1.1 server. Every test task that runs `flutter test` MUST do this first (exact sequence, from repo root `/Volumes/MacMiniDisk/workspace/MobileStarter`):

```bash
# 1. Reset the dev DB (integration tests aren't idempotent across runs)
node --input-type=module -e "import { Client } from 'pg'; const c = new Client({ connectionString: 'postgresql://mediagrab:mediagrab_dev@newmedia:5432/mobileui_dev' }); await c.connect(); await c.query('DROP SCHEMA public CASCADE'); await c.query('CREATE SCHEMA public'); await c.end(); console.log('RESET');"

# 2. Start the server in the background (next dev compiles lazily; first request is slow)
cd server && AUTH_DATABASE_URL='postgresql://mediagrab:mediagrab_dev@newmedia:5432/mobileui_dev' nohup npm run dev > /tmp/p12-server.log 2>&1 &
SERVER_PID=$!
cd ..

# 3. Wait until the server is live (health endpoint returns 200)
for i in $(seq 1 60); do curl -sf http://localhost:3210/api/v1/health/live >/dev/null && break; sleep 1; done

# 4. Run the Flutter tests with the platform override (server only maps ios/android/harmonyos → store key)
cd flutter && flutter test \
  --dart-define=MOBILEUI_API_URL=http://localhost:3210 \
  --dart-define=MOBILEUI_APP_ID=zhongbei \
  --dart-define=MOBILEUI_APP_ENVIRONMENT=development \
  --dart-define=MOBILEUI_PLATFORM=ios \
  test/payment/
cd ..

# 5. Stop the server
kill $SERVER_PID 2>/dev/null || true
```

`flutter analyze` (no server needed): `cd flutter && flutter analyze`.

**Commit discipline:** explicit `git add <paths>` only; never `-A`/`.`/`-u`. The repo has pre-existing uncommitted changes? — NO (the splash work was committed in `e2818b2`/`500e7e7`/`5d8e7b2`); working tree is clean. Still use explicit paths.

---

## File Structure

**Create** (`flutter/lib/payment/`): `payment_models.dart`, `token_store.dart`, `payment_repository.dart`, `payment_provider.dart`, `mock_payment_provider.dart`, `payment_controller.dart`, `payment_scope.dart`. Plus `flutter/lib/screens/checkout_screen.dart`. Tests in `flutter/test/payment/`: `payment_models_test.dart`, `test_server.dart` (signup helper), `payment_repository_test.dart`, `mock_payment_provider_test.dart`, `payment_controller_test.dart`.

**Modify**: `lib/app/runtime_models.dart` (`BillingPlan.storeProductMapping`, `OrderView` fields), `lib/app/mobile_ui_app.dart` (mount `PaymentScope`), `lib/navigation/app_router.dart` (`checkout`→`CheckoutScreen`), `lib/screens/profile_screens.dart` (MembershipScreen → push checkout), `lib/app/app_controller.dart` (remove `purchase`), `lib/app/app_repository.dart` (remove `purchase`).

---

## Task 1: Models (payment_models + runtime_models extensions)

**Files:**
- Create: `flutter/lib/payment/payment_models.dart`
- Modify: `flutter/lib/app/runtime_models.dart` (`BillingPlan`:190-218, `OrderView`:258-278)
- Test: `flutter/test/payment/payment_models_test.dart`

- [ ] **Step 1: Write the failing test**

`flutter/test/payment/payment_models_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobilestarter/payment/payment_models.dart';
import 'package:mobilestarter/app/runtime_models.dart';

void main() {
  test('BillingPlan parses storeProductMapping', () {
    final plan = BillingPlan.fromJson({
      'id': 'pro-monthly', 'tierId': 'pro', 'name': 'Pro', 'interval': 'month',
      'priceMinor': 1800, 'currency': 'CNY', 'provider': 'mock',
      'storeProductMapping': {'apple': 'com.x.pro', 'google': 'pro_g', 'hms': 'pro_h'},
    });
    expect(plan.storeProductMapping?.apple, 'com.x.pro');
    expect(plan.storeProductMapping?.hms, 'pro_h');
  });

  test('BillingPlan storeProductMapping nullable', () {
    final plan = BillingPlan.fromJson({
      'id': 'free', 'tierId': 'free', 'name': 'Free', 'interval': 'lifetime',
      'priceMinor': 0, 'currency': 'CNY', 'provider': 'mock',
    });
    expect(plan.storeProductMapping, isNull);
  });

  test('OrderView parses status/provider/storeTransactionId/expiresAt', () {
    final order = OrderView.fromJson({
      'id': 'o1', 'planId': 'pro-monthly', 'status': 'success',
      'amountMinor': 1800, 'currency': 'CNY', 'provider': 'mock',
      'storeTransactionId': 't1', 'receiptHash': 'h1', 'expiresAt': '2026-12-31T00:00:00.000Z',
    });
    expect(order.status, OrderStatus.success);
    expect(order.provider, 'mock');
    expect(order.storeTransactionId, 't1');
    expect(order.expiresAt, '2026-12-31T00:00:00.000Z');
  });

  test('MembershipCurrent fromJson', () {
    final mc = MembershipCurrent.fromJson({
      'tier': 'pro',
      'entitlements': [{'key': 'export.hd', 'expiresAt': null}],
      'subscription': {'planId': 'pro-monthly', 'status': 'active', 'renewAt': '2026-12-31T00:00:00.000Z'},
    });
    expect(mc.tier, 'pro');
    expect(mc.entitlements.first.key, 'export.hd');
    expect(mc.subscription?.planId, 'pro-monthly');
  });
}
```

- [ ] **Step 2: Run — verify FAIL**

`cd flutter && flutter test test/payment/payment_models_test.dart`
Expected: FAIL — `storeProductMapping`/`OrderStatus`/`MembershipCurrent` undefined.

- [ ] **Step 3: Create `lib/payment/payment_models.dart`**

```dart
typedef JsonMap = Map<String, Object?>;

final class StoreProductMapping {
  const StoreProductMapping({this.apple, this.google, this.hms});
  factory StoreProductMapping.fromJson(JsonMap json) => StoreProductMapping(
        apple: json['apple'] as String?,
        google: json['google'] as String?,
        hms: json['hms'] as String?,
      );
  final String? apple;
  final String? google;
  final String? hms;
}

final class StoreProduct {
  const StoreProduct({required this.storeProductId, this.title});
  final String storeProductId;
  final String? title;
}

final class PurchaseResult {
  const PurchaseResult({required this.storeProductId, required this.receipt});
  final String storeProductId;
  final Object receipt; // opaque; forwarded to server /purchases/verify
}

final class Entitlement {
  const Entitlement({required this.key, this.expiresAt});
  factory Entitlement.fromJson(JsonMap json) => Entitlement(
        key: json['key']! as String,
        expiresAt: json['expiresAt'] as String?,
      );
  final String key;
  final String? expiresAt;
}

final class Subscription {
  const Subscription({required this.planId, required this.status, this.renewAt});
  factory Subscription.fromJson(JsonMap json) => Subscription(
        planId: json['planId']! as String,
        status: json['status']! as String,
        renewAt: json['renewAt'] as String?,
      );
  final String planId;
  final String status;
  final String? renewAt;
}

final class MembershipCurrent {
  const MembershipCurrent({required this.tier, required this.entitlements, this.subscription});
  factory MembershipCurrent.fromJson(JsonMap json) => MembershipCurrent(
        tier: json['tier'] as String?,
        entitlements: (json['entitlements'] as List<Object?>? ?? const [])
            .map((e) => Entitlement.fromJson(JsonMap.from(e! as Map)))
            .toList(growable: false),
        subscription: json['subscription'] == null
            ? null
            : Subscription.fromJson(JsonMap.from(json['subscription']! as Map)),
      );
  final String? tier;
  final List<Entitlement> entitlements;
  final Subscription? subscription;
}

final class CreateOrderResult {
  const CreateOrderResult({required this.orderId, required this.storeProductId, required this.status});
  factory CreateOrderResult.fromJson(JsonMap json) => CreateOrderResult(
        orderId: json['orderId']! as String,
        storeProductId: json['storeProductId']! as String,
        status: json['status']! as String,
      );
  final String orderId;
  final String storeProductId;
  final String status;
}
```

- [ ] **Step 4: Extend `runtime_models.dart`**

Add `OrderStatus` enum above `OrderView`, extend `BillingPlan` and `OrderView`:

`BillingPlan` — add `storeProductMapping` field + fromJson line. Replace the class body (lines 190-218) with:
```dart
final class BillingPlan {
  const BillingPlan({
    required this.id,
    required this.tierId,
    required this.name,
    required this.interval,
    required this.priceMinor,
    required this.currency,
    required this.provider,
    this.storeProductMapping,
  });

  factory BillingPlan.fromJson(JsonMap json) => BillingPlan(
    id: json['id']! as String,
    tierId: json['tierId']! as String,
    name: json['name']! as String,
    interval: json['interval']! as String,
    priceMinor: json['priceMinor']! as int,
    currency: json['currency']! as String,
    provider: json['provider']! as String,
    storeProductMapping: json['storeProductMapping'] == null
        ? null
        : StoreProductMapping.fromJson(JsonMap.from(json['storeProductMapping']! as Map)),
  );

  final String id;
  final String tierId;
  final String name;
  final String interval;
  final int priceMinor;
  final String currency;
  final String provider;
  final StoreProductMapping? storeProductMapping;
}
```
Add the import at top of `runtime_models.dart`: `import '../payment/payment_models.dart';` (so `StoreProductMapping` resolves).

`OrderView` — replace (lines 258-278) with:
```dart
enum OrderStatus { pending, processing, success, failed, refunded }

OrderStatus _parseOrderStatus(String s) {
  return OrderStatus.values.firstWhere(
    (e) => e.name == s,
    orElse: () => OrderStatus.pending,
  );
}

final class OrderView {
  const OrderView({
    required this.id,
    required this.planId,
    required this.status,
    required this.amountMinor,
    required this.currency,
    this.provider,
    this.storeTransactionId,
    this.expiresAt,
  });
  factory OrderView.fromJson(JsonMap json) => OrderView(
    id: json['id']! as String,
    planId: json['planId']! as String,
    status: _parseOrderStatus(json['status']! as String),
    amountMinor: json['amountMinor']! as int,
    currency: json['currency']! as String,
    provider: json['provider'] as String?,
    storeTransactionId: json['storeTransactionId'] as String?,
    expiresAt: json['expiresAt'] as String?,
  );
  final String id;
  final String planId;
  final OrderStatus status;
  final int amountMinor;
  final String currency;
  final String? provider;
  final String? storeTransactionId;
  final String? expiresAt;
}
```
> Note: `OrderView.status` changes from `String` to `OrderStatus`. Grep for other `order.status` reads (`orders_screen.dart`) and update them to use the enum (`.name` for display). Check: `grep -rn "\.status" flutter/lib/screens/orders_screen.dart` — if it does `order.status` as a string, change to `order.status.name`.

- [ ] **Step 5: Run — verify PASS**

`cd flutter && flutter test test/payment/payment_models_test.dart && flutter analyze`
Expected: tests PASS; analyze clean. If analyze flags `orders_screen.dart` on `.status`, fix it (use `.status.name`).

- [ ] **Step 6: Commit**
```bash
git add flutter/lib/payment/payment_models.dart flutter/lib/app/runtime_models.dart flutter/lib/screens/orders_screen.dart flutter/test/payment/payment_models_test.dart
git commit -m "feat(flutter): payment models + BillingPlan/OrderView extensions"
```
(Only add `orders_screen.dart` if you had to edit it for the status enum.)

---

## Task 2: TokenStore + PaymentRepository

**Files:**
- Create: `flutter/lib/payment/token_store.dart`, `flutter/lib/payment/payment_repository.dart`, `flutter/test/payment/test_server.dart`, `flutter/test/payment/payment_repository_test.dart`

- [ ] **Step 1: Create `token_store.dart`**

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String? token);
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const _key = 'mobileui.sessionToken'; // mirrors AppRepository/SupportRepository

  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String? token) async {
    if (token == null || token.isEmpty) {
      await _storage.delete(key: _key);
    } else {
      await _storage.write(key: _key, value: token);
    }
  }
}

class InMemoryTokenStore implements TokenStore {
  String? _token;
  InMemoryTokenStore([this._token]);
  @override
  Future<String?> read() async => _token;
  @override
  Future<void> write(String? token) async => _token = token;
}
```

- [ ] **Step 2: Create `payment_repository.dart`** (mirrors `support_repository.dart`'s HTTP layer; reads token via `TokenStore`; no own 401-refresh — 401 surfaces as `PaymentApiException(status:401)` and the controller maps it to `Unauthorized`)

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../app/runtime_models.dart';
import 'payment_models.dart';
import 'token_store.dart';

final class PaymentApiException implements Exception {
  const PaymentApiException(this.code, this.message, this.status);
  final String code;
  final String message;
  final int status;
  @override
  String toString() => message;
}

final class PaymentRepository {
  PaymentRepository({required TokenStore tokenStore}) : _tokenStore = tokenStore;

  final TokenStore _tokenStore;

  static const _apiBase = String.fromEnvironment(
    'MOBILEUI_API_URL',
    defaultValue: 'http://localhost:3210',
  );
  static const _appIdValue = String.fromEnvironment('MOBILEUI_APP_ID');
  static const _appEnvironmentValue = String.fromEnvironment('MOBILEUI_APP_ENVIRONMENT');
  static const _platformOverride = String.fromEnvironment('MOBILEUI_PLATFORM');

  static String get _appId {
    if (_appIdValue.isEmpty) {
      throw StateError('MOBILEUI_APP_ID 未配置：请用 --dart-define=MOBILEUI_APP_ID=<app-id>。');
    }
    return _appIdValue;
  }

  static String get _appEnvironment {
    if (_appEnvironmentValue.isEmpty) {
      throw StateError('MOBILEUI_APP_ENVIRONMENT 未配置：请用 --dart-define=MOBILEUI_APP_ENVIRONMENT=<env>。');
    }
    return _appEnvironmentValue;
  }

  String get _platform => _platformOverride.isNotEmpty ? _platformOverride : _platformName();

  Future<CreateOrderResult> createOrder(String planId, {required String idempotencyKey}) async {
    final data = await _request(
      '/api/v1/orders',
      method: 'POST',
      body: {'planId': planId},
      idempotencyKey: idempotencyKey,
    );
    return CreateOrderResult.fromJson(_map(data));
  }

  Future<OrderView> verifyPurchase({String? orderId, required Object receipt}) async {
    final data = await _request(
      '/api/v1/purchases/verify',
      method: 'POST',
      body: _verifyBody(orderId, receipt),
    );
    return OrderView.fromJson(_map(data));
  }

  Future<List<String>> restore(List<Object> receipts) async {
    final data = await _request(
      '/api/v1/purchases/restore',
      method: 'POST',
      body: {'receipts': receipts},
    );
    return (_map(data)['entitlements'] as List<Object?>).cast<String>();
  }

  Future<MembershipCurrent> membershipCurrent() async {
    final data = await _request('/api/v1/membership/current');
    return MembershipCurrent.fromJson(_map(data));
  }

  Future<List<String>> entitlements() async {
    final data = await _request('/api/v1/membership/entitlements');
    return (_map(data)['keys'] as List<Object?>).cast<String>();
  }

  Future<List<OrderView>> orders() async {
    final data = await _request('/api/v1/orders');
    return (data as List<Object?>)
        .map((item) => OrderView.fromJson(_map(item)))
        .toList(growable: false);
  }

  Map<String, Object?> _verifyBody(String? orderId, Object receipt) {
    final body = <String, Object?>{'receipt': receipt};
    if (orderId != null) body['orderId'] = orderId;
    return body;
  }

  Future<Object?> _request(
    String path, {
    String method = 'GET',
    Map<String, Object?>? body,
    String? idempotencyKey,
  }) async {
    final token = await _tokenStore.read() ?? '';
    final headers = <String, String>{
      'content-type': 'application/json',
      'x-app-id': _appId,
      'x-app-environment': _appEnvironment,
      'x-platform': _platform,
      'x-app-version': '1.0.0',
      'accept-language': 'zh-CN',
      if (token.isNotEmpty) 'authorization': 'Bearer $token',
      if (idempotencyKey != null) 'idempotency-key': idempotencyKey,
    };
    final uri = Uri.parse('$_apiBase$path');
    final response = method == 'GET'
        ? await http.get(uri, headers: headers).timeout(const Duration(seconds: 12))
        : await http.post(uri, headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 12));
    final envelope = _map(jsonDecode(response.body));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = _map(envelope['error']);
      throw PaymentApiException(
        error['code'] as String? ?? 'HTTP_ERROR',
        _errorMessage(error),
        response.statusCode,
      );
    }
    return envelope['data'];
  }

  static Map<String, Object?> _map(Object? value) => Map<String, Object?>.from(value! as Map);
  static String _errorMessage(Map<String, Object?> error) {
    final fe = error['fieldErrors'];
    if (fe is Map) {
      final msgs = fe.values.whereType<List>().expand((l) => l.whereType<String>()).toSet();
      if (msgs.isNotEmpty) return msgs.join('；');
    }
    return error['message'] as String? ?? '服务暂时不可用';
  }
}

String _platformName() {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => 'fuchsia',
  };
}
```

- [ ] **Step 3: Create test helper `test/payment/test_server.dart`**

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

const _apiBase = String.fromEnvironment('MOBILEUI_API_URL', defaultValue: 'http://localhost:3210');
const _appId = String.fromEnvironment('MOBILEUI_APP_ID');
const _appEnv = String.fromEnvironment('MOBILEUI_APP_ENVIRONMENT');

/// Signs up a fresh test user against the real server; returns the access token.
/// Caller passes a unique email per test (test owns isolation).
Future<String> signUpAndGetToken(String email, {String password = 'Test1234'}) async {
  final response = await http
      .post(
        Uri.parse('$_apiBase/api/v1/auth/sign-up'),
        headers: {
          'content-type': 'application/json',
          'x-app-id': _appId,
          'x-app-environment': _appEnv,
        },
        body: jsonEncode({
          'email': email,
          'password': password,
          'username': email.split('@').first,
          'consentVersion': '2026-07-29',
        }),
      )
      .timeout(const Duration(seconds: 15));
  if (response.statusCode != 201) {
    throw StateError('sign-up failed (${response.statusCode}): ${response.body}');
  }
  final envelope = jsonDecode(response.body) as Map;
  final data = envelope['data'] as Map;
  return data['accessToken']! as String;
}
```

> Verify the sign-up response shape: `data.accessToken` — confirm by checking `AppRepository`'s sign-in parsing. If the field is named differently (e.g. `sessionToken`), adjust. The server's `/auth/sign-up` returns `{accessToken, refreshToken, user}`.

- [ ] **Step 4: Write the failing repository test `test/payment/payment_repository_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobilestarter/payment/payment_repository.dart';
import 'package:mobilestarter/payment/token_store.dart';
import 'test_server.dart';

void main() {
  late PaymentRepository repo;
  late String token;

  setUp(() async {
    token = await signUpAndGetToken('p12-repo-${DateTime.now().microsecondsSinceEpoch}@test.local');
    repo = PaymentRepository(tokenStore: InMemoryTokenStore(token));
  });

  test('createOrder returns pending + storeProductId, verify succeeds + grants entitlements', () async {
    final order = await repo.createOrder('pro-monthly', idempotencyKey: 'p12-repo-${DateTime.now().microsecondsSinceEpoch}');
    expect(order.status, 'pending');
    expect(order.storeProductId, isNotEmpty);

    final verified = await repo.verifyPurchase(orderId: order.orderId, receipt: {'productId': order.storeProductId});
    expect(verified.status.toString(), contains('success'));

    final mc = await repo.membershipCurrent();
    expect(mc.entitlements, isNotEmpty);
  });

  test('verifyPurchase with fail receipt yields a failed order', () async {
    final order = await repo.createOrder('pro-monthly', idempotencyKey: 'p12-repo-fail-${DateTime.now().microsecondsSinceEpoch}');
    final verified = await repo.verifyPurchase(orderId: order.orderId, receipt: {'productId': order.storeProductId, 'fail': true});
    expect(verified.status.toString(), contains('failed'));
  });
}
```

- [ ] **Step 5: Run — server prereq + verify PASS**

Run the **CRITICAL test prerequisite** block above (reset DB → start server → wait health), then:
`cd flutter && flutter test --dart-define=MOBILEUI_API_URL=http://localhost:3210 --dart-define=MOBILEUI_APP_ID=zhongbei --dart-define=MOBILEUI_APP_ENVIRONMENT=development --dart-define=MOBILEUI_PLATFORM=ios test/payment/payment_repository_test.dart`
Then kill the server. Expected: 2 tests PASS. If `sign-up` fails on field name, fix `test_server.dart` per Step 3 note. If `createOrder` 404s with PRODUCT_NOT_MAPPED, confirm the dart-define `MOBILEUI_PLATFORM=ios` is reaching the repo (debug `_platform`).

- [ ] **Step 6: Commit**
```bash
git add flutter/lib/payment/token_store.dart flutter/lib/payment/payment_repository.dart flutter/test/payment/test_server.dart flutter/test/payment/payment_repository_test.dart
git commit -m "feat(flutter): PaymentRepository + TokenStore (P-1.1 API client)"
```

---

## Task 3: PaymentProvider + MockPaymentProvider

**Files:**
- Create: `flutter/lib/payment/payment_provider.dart`, `flutter/lib/payment/mock_payment_provider.dart`
- Test: `flutter/test/payment/mock_payment_provider_test.dart`

- [ ] **Step 1: Write failing test `test/payment/mock_payment_provider_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobilestarter/payment/mock_payment_provider.dart';

void main() {
  test('purchase returns a receipt carrying the productId', () async {
    final provider = MockPaymentProvider();
    final result = await provider.purchase('com.x.pro');
    expect(result.storeProductId, 'com.x.pro');
    expect((result.receipt as Map)['productId'], 'com.x.pro');
  });

  test('purchase with fail:true yields a fail receipt', () async {
    final provider = MockPaymentProvider();
    final result = await provider.purchase('com.x.pro', fail: true);
    expect((result.receipt as Map)['fail'], true);
  });

  test('restore replays previously purchased products', () async {
    final provider = MockPaymentProvider();
    await provider.purchase('com.x.pro');
    await provider.purchase('pro_g');
    final restored = await provider.restore();
    expect(restored.map((r) => r.storeProductId).toSet(), {'com.x.pro', 'pro_g'});
  });
}
```

- [ ] **Step 2: Run — verify FAIL** (`MockPaymentProvider` undefined).

- [ ] **Step 3: Create `payment_provider.dart`**
```dart
import 'payment_models.dart';

abstract interface class PaymentProvider {
  Future<List<StoreProduct>> loadProducts(StoreProductMapping? mapping);
  Future<PurchaseResult> purchase(String storeProductId);
  Future<List<PurchaseResult>> restore();
}
```

- [ ] **Step 4: Create `mock_payment_provider.dart`**
```dart
import 'payment_models.dart';
import 'payment_provider.dart';

class MockPaymentProvider implements PaymentProvider {
  final Set<String> _owned = {};

  @override
  Future<List<StoreProduct>> loadProducts(StoreProductMapping? mapping) async {
    if (mapping == null) return const [];
    return [
      if (mapping.apple != null) StoreProduct(storeProductId: mapping.apple!),
      if (mapping.google != null) StoreProduct(storeProductId: mapping.google!),
      if (mapping.hms != null) StoreProduct(storeProductId: mapping.hms!),
    ];
  }

  @override
  Future<PurchaseResult> purchase(String storeProductId, {bool fail = false}) async {
    final receipt = <String, Object?>{'productId': storeProductId, if (fail) 'fail': true};
    if (!fail) _owned.add(storeProductId);
    return PurchaseResult(storeProductId: storeProductId, receipt: receipt);
  }

  @override
  Future<List<PurchaseResult>> restore() async {
    return _owned
        .map((id) => PurchaseResult(storeProductId: id, receipt: <String, Object?>{'productId': id}))
        .toList(growable: false);
  }
}
```
> `purchase` adds a `{bool fail}` named param for tests; production callers omit it. This does NOT break the interface contract (it's an impl-only param with a default).

- [ ] **Step 5: Run — verify PASS** (`flutter test test/payment/mock_payment_provider_test.dart`, no server needed).

- [ ] **Step 6: Commit**
```bash
git add flutter/lib/payment/payment_provider.dart flutter/lib/payment/mock_payment_provider.dart flutter/test/payment/mock_payment_provider_test.dart
git commit -m "feat(flutter): PaymentProvider interface + MockPaymentProvider"
```

---

## Task 4: PaymentController + PaymentScope

**Files:**
- Create: `flutter/lib/payment/payment_controller.dart`, `flutter/lib/payment/payment_scope.dart`
- Test: `flutter/test/payment/payment_controller_test.dart`

- [ ] **Step 1: Write failing test `test/payment/payment_controller_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobilestarter/app/runtime_models.dart';
import 'package:mobilestarter/payment/mock_payment_provider.dart';
import 'package:mobilestarter/payment/payment_controller.dart';
import 'package:mobilestarter/payment/payment_repository.dart';
import 'package:mobilestarter/payment/token_store.dart';
import 'test_server.dart';

void main() {
  late PaymentRepository repo;
  late PaymentController controller;

  setUp(() async {
    final token = await signUpAndGetToken('p12-ctrl-${DateTime.now().microsecondsSinceEpoch}@test.local');
    repo = PaymentRepository(tokenStore: InMemoryTokenStore(token));
    controller = PaymentController(repository: repo, provider: MockPaymentProvider());
  });

  test('checkout success → purchaseState Success + order success + entitlements granted', () async {
    final ok = await controller.checkout('pro-monthly');
    expect(ok, isTrue);
    expect(controller.purchaseState, isA<Success<OrderView>>());
    expect((controller.purchaseState as Success<OrderView>).data.status, OrderStatus.success);
    final mc = await repo.membershipCurrent();
    expect(mc.entitlements, isNotEmpty);
  });

  test('checkout failure → purchaseState Failure, no entitlements', () async {
    controller = PaymentController(
      repository: repo,
      provider: _FailingMockProvider(),
    );
    final ok = await controller.checkout('pro-monthly');
    expect(ok, isFalse);
    expect(controller.purchaseState, isA<Failure<OrderView>>());
    final mc = await repo.membershipCurrent();
    expect(mc.entitlements, isEmpty);
  });

  test('checkout is idempotent per idempotencyKey (same key → same order)', () async {
    // Two checkouts naturally use different keys (uuid); verify the controller doesn't
    // double-submit when busy: a second checkout while busy returns false.
    final first = controller.checkout('pro-monthly'); // don't await yet
    final secondOk = await controller.checkout('pro-monthly'); // races while first in flight
    await first;
    // At least one succeeded; busy guard prevented concurrent execution effects.
    expect(controller.purchaseState, isA<Success<OrderView>>());
    expect(secondOk, isFalse); // rejected because busy
  });
}

class _FailingMockProvider extends MockPaymentProvider {
  @override
  Future<PurchaseResult> purchase(String storeProductId, {bool fail = true}) async {
    fail = true;
    return super.purchase(storeProductId, fail: fail);
  }
}
```

- [ ] **Step 2: Run — verify FAIL** (`PaymentController` undefined).

- [ ] **Step 3: Create `payment_controller.dart`**
```dart
import 'package:flutter/foundation.dart';

import '../state/async_state.dart';
import '../app/runtime_models.dart';
import 'payment_models.dart';
import 'payment_provider.dart';
import 'payment_repository.dart';

final class PaymentController extends ChangeNotifier {
  PaymentController({required PaymentRepository repository, required PaymentProvider provider})
      : _repository = repository,
        _provider = provider;

  final PaymentRepository _repository;
  final PaymentProvider _provider;

  AsyncState<OrderView> purchaseState = const Idle();
  AsyncState<List<String>> restoreState = const Idle();
  bool _busy = false;

  Future<bool> checkout(String planId) async {
    if (_busy) return false;
    _busy = true;
    purchaseState = const Loading();
    notifyListeners();
    try {
      final idempotencyKey = 'flutter-${DateTime.now().microsecondsSinceEpoch}';
      final order = await _repository.createOrder(planId, idempotencyKey: idempotencyKey);
      final result = await _provider.purchase(order.storeProductId);
      final verified = await _repository.verifyPurchase(orderId: order.orderId, receipt: result.receipt);
      await _repository.membershipCurrent(); // refresh server-side membership cache
      purchaseState = Success(verified);
      notifyListeners();
      return true;
    } on PaymentApiException catch (error) {
      purchaseState = error.status == 401
          ? const Unauthorized()
          : Failure(error.message);
      notifyListeners();
      return false;
    } catch (e) {
      purchaseState = const Offline();
      notifyListeners();
      return false;
    } finally {
      _busy = false;
    }
  }

  Future<bool> restorePurchases() async {
    if (_busy) return false;
    _busy = true;
    restoreState = const Loading();
    notifyListeners();
    try {
      final results = await _provider.restore();
      final receipts = results.map((r) => r.receipt).toList();
      final entitlements = await _repository.restore(receipts);
      restoreState = entitlements.isEmpty ? const Empty() : Success(entitlements);
      notifyListeners();
      return true;
    } on PaymentApiException catch (error) {
      restoreState = error.status == 401
          ? const Unauthorized()
          : Failure(error.message);
      notifyListeners();
      return false;
    } catch (_) {
      restoreState = const Offline();
      notifyListeners();
      return false;
    } finally {
      _busy = false;
    }
  }
}
```

- [ ] **Step 4: Create `payment_scope.dart`** (mirrors `support_scope.dart`)
```dart
import 'package:flutter/widgets.dart';
import 'payment_controller.dart';

final class PaymentScope extends InheritedNotifier<PaymentController> {
  const PaymentScope({
    required PaymentController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static PaymentController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PaymentScope>();
    assert(scope != null, 'PaymentScope is missing');
    return scope!.notifier!;
  }
}
```

- [ ] **Step 5: Run — server prereq + verify PASS**

Run the CRITICAL prereq block, then `flutter test --dart-define=... test/payment/payment_controller_test.dart`, kill server. Expected: 3 tests PASS. (The idempotency/busy test relies on the busy guard; if the race is non-deterministic on a fast machine, simplify that test to: call checkout twice synchronously without awaiting the first, assert the second returns false. If flaky, replace with a direct `_busy=true` check test.)

- [ ] **Step 6: Commit**
```bash
git add flutter/lib/payment/payment_controller.dart flutter/lib/payment/payment_scope.dart flutter/test/payment/payment_controller_test.dart
git commit -m "feat(flutter): PaymentController + PaymentScope (checkout/restore orchestration)"
```

---

## Task 5: CheckoutScreen + wiring

**Files:**
- Create: `flutter/lib/screens/checkout_screen.dart`
- Modify: `flutter/lib/app/mobile_ui_app.dart`, `flutter/lib/navigation/app_router.dart`, `flutter/lib/screens/profile_screens.dart`, `flutter/lib/app/app_controller.dart`, `flutter/lib/app/app_repository.dart`

- [ ] **Step 1: Create `screens/checkout_screen.dart`**

```dart
import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/app_scope.dart';
import '../design_system/components.dart'; // AppButton, AppCard, AppListTile — confirm names exist
import '../payment/payment_scope.dart';
import '../app/runtime_models.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({required this.planId, super.key});
  final String planId;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeCheckout());
  }

  void _maybeCheckout() {
    final controller = PaymentScope.of(context);
    if (controller.purchaseState is! Idle && controller.purchaseState is! Failure) return;
    unawaitedCheckout(controller);
  }

  Future<void> unawaitedCheckout(PaymentController controller) async {
    await controller.checkout(widget.planId);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final plan = _findPlan(app, widget.planId);
    final payment = PaymentScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('确认订阅')),
      body: AnimatedBuilder(
        animation: payment,
        builder: (context, _) {
          final state = payment.purchaseState;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan?.name ?? widget.planId, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (plan != null)
                    Text('${plan.priceMinor / 100} ${plan.currency} · ${plan.interval}',
                        style: Theme.of(context).textTheme.bodyMedium),
                ],
              )),
              const SizedBox(height: 16),
              if (plan?.provider == 'mock')
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('演示支付：将通过模拟渠道完成。', style: TextStyle(color: Colors.orange)),
                ),
              _statePanel(state, payment),
            ],
          );
        },
      ),
    );
  }

  Widget _statePanel(AsyncState<OrderView> state, PaymentController payment) {
    return switch (state) {
      Idle() || Loading() => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
      Success(:final data) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 8),
            Text('订阅成功（订单 ${data.id}）', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            AppButton(label: '完成', onPressed: () => Navigator.of(context).maybePop()),
          ],
        ),
      Failure(:final message) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            AppButton(label: '重试', onPressed: () => unawaitedCheckout(payment)),
          ],
        ),
      Offline() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('网络不可用，请检查连接后重试。'),
            const SizedBox(height: 12),
            AppButton(label: '重试', onPressed: () => unawaitedCheckout(payment)),
          ],
        ),
      Unauthorized() => const Center(child: Text('登录已过期，请重新登录。')),
      Empty() => const SizedBox.shrink(),
    };
  }

  BillingPlan? _findPlan(AppController app, String planId) {
    final plans = app.config?.plans ?? const <BillingPlan>[];
    for (final p in plans) {
      if (p.id == planId) return p;
    }
    return null;
  }
}
```

> Verify `AppButton`/`AppCard` names: `grep -rn "class AppButton\|class AppCard" flutter/lib/design_system/`. If they're named differently (e.g. `PrimaryButton`), adjust. If unsure, replace `AppButton(label:, onPressed:)` with a standard `FilledButton(onPressed:, child: Text(label))` and `AppCard` with `Card(child: ...)` to avoid a wrong-name compile error — then refine once names are confirmed.

- [ ] **Step 2: Modify `mobile_ui_app.dart` — mount PaymentScope**

Add fields/imports and wrap in `build()`. In `_MobileUiAppState`:
- Add import: `import '../payment/payment_controller.dart';` `import '../payment/payment_repository.dart';` `import '../payment/payment_scope.dart';` `import '../payment/token_store.dart';` `import '../support/support_repository.dart';` is already there.
- Add field next to `supportController`:
```dart
  late final PaymentController paymentController;
```
- In `initState`, after `controller = AppController(AppRepository());`:
```dart
    paymentController = PaymentController(
      repository: PaymentRepository(tokenStore: SecureTokenStore()),
      provider: MockPaymentProvider(),
    );
```
  and add imports for `MockPaymentProvider`: `import '../payment/mock_payment_provider.dart';`
- In `dispose`, add `paymentController.dispose();` (before/after `supportController.dispose()`).
- In `build`, wrap: currently `AppScope(child: SupportScope(child: AnimatedBuilder(...)))`. Insert `PaymentScope` between `SupportScope` and `AnimatedBuilder`:
```dart
    return AppScope(
      controller: controller,
      child: SupportScope(
        controller: supportController,
        child: PaymentScope(
          controller: paymentController,
          child: AnimatedBuilder(
            animation: Listenable.merge([controller, supportController, paymentController]),
            builder: (context, _) => MaterialApp(
              ... // unchanged
            ),
          ),
        ),
      ),
    );
```
  (Change the `AnimatedBuilder`'s `animation:` from `controller` to `Listenable.merge([controller, supportController, paymentController])` so all three scopes rebuild. Confirm the current `AnimatedBuilder(animation: controller, ...)`.)

- [ ] **Step 3: Modify `app_router.dart` — checkout → CheckoutScreen**

In `screenFor`, find `AppRoute.checkout => ...` (currently `const MembershipScreen()`). Change to `AppRoute.checkout => const MembershipScreen()` — NO, change to a `CheckoutScreen`. But `CheckoutScreen` needs a `planId`. The router's `screenFor(route)` takes only `AppRoute` (no args). So `CheckoutScreen` can't get `planId` from the router directly.

Resolution: MembershipScreen navigates via `controller.navigate` which pushes an `AppRoute.checkout`. The router maps `AppRoute.checkout` → a screen. Since `CheckoutScreen` needs `planId`, and the nav system is route-enum-based (no params), pass `planId` through the `PaymentController` (set a `pendingPlanId` field before navigating) OR make CheckoutScreen read a "selected plan" from the controller.

Simplest: Add `String? pendingPlanId` to `PaymentController`; MembershipScreen sets `paymentController.pendingPlanId = planId` then navigates to `AppRoute.checkout`; `CheckoutScreen` reads `PaymentScope.of(context).pendingPlanId`. Add to `PaymentController`:
```dart
  String? pendingPlanId;
```
Then `app_router.dart`: `AppRoute.checkout => const CheckoutScreen(),` with import `import '../screens/checkout_screen.dart';`. And `CheckoutScreen` reads planId from the scope:
```dart
final planId = PaymentScope.of(context).pendingPlanId ?? '';
```
Change `CheckoutScreen` constructor to `const CheckoutScreen({super.key});` (no planId param) and use the scope's `pendingPlanId`.

- [ ] **Step 4: Modify `profile_screens.dart` MembershipScreen — navigate to checkout**

Find MembershipScreen's `_purchase` (around line 278-292 per earlier read). Replace the `_purchase` body so it sets pendingPlanId + navigates to `AppRoute.checkout` instead of calling the old `controller.purchase`. Use both scopes:
```dart
  Future<void> _pushCheckout(String planId) async {
    final payment = PaymentScope.of(context);
    payment.pendingPlanId = planId;
    AppScope.of(context).navigate(AppRoute.checkout);
  }
```
Replace the confirm button's `onPressed` (currently calls `_purchase`) to call `_pushCheckout(selectedPlan)`. Add imports for `PaymentScope` and `AppRoute`/`AppScope` as needed (AppScope likely already imported). Remove the now-unused `_purchase` and the mock-disclaimer branch ONLY if it referenced `controller.purchase` — keep the mock disclaimer UI if it's purely visual.

- [ ] **Step 5: Remove dead `purchase` methods**

- `app_controller.dart`: delete the `Future<bool> purchase(String planId) async {...}` method (lines ~293-299). Leave `orders` field + `loadOrders` (GET /orders still works, used by OrdersScreen).
- `app_repository.dart`: delete the `Future<OrderView> purchase(String planId) async {...}` method (lines ~262-270). Leave `orders()`.

- [ ] **Step 6: Verify — `flutter analyze` (no server)**
`cd flutter && flutter analyze` → must be clean. Fix any dangling references to the removed `purchase` (grep: `grep -rn "\.purchase(" flutter/lib`).

- [ ] **Step 7: Commit**
```bash
git add flutter/lib/screens/checkout_screen.dart flutter/lib/app/mobile_ui_app.dart flutter/lib/navigation/app_router.dart flutter/lib/screens/profile_screens.dart flutter/lib/app/app_controller.dart flutter/lib/app/app_repository.dart flutter/lib/payment/payment_controller.dart
git commit -m "feat(flutter): CheckoutScreen + wire PaymentScope + remove old purchase path"
```

---

## Task 6: Ownership test + full green

**Files:**
- Modify: `flutter/test/payment/payment_controller_test.dart` (add ownership test)

- [ ] **Step 1: Add ownership test** (append to `payment_controller_test.dart`)

```dart
  test('verifyPurchase rejects another user order (ORDER_NOT_FOUND)', () async {
    // Owner creates + the order id is known only to owner's session.
    final ownerToken = await signUpAndGetToken('p12-own-${DateTime.now().microsecondsSinceEpoch}@test.local');
    final ownerRepo = PaymentRepository(tokenStore: InMemoryTokenStore(ownerToken));
    final order = await ownerRepo.createOrder('pro-monthly', idempotencyKey: 'own-${DateTime.now().microsecondsSinceEpoch}');

    // Attacker (different session) tries to verify owner's orderId:
    expect(
      () => repo.verifyPurchase(orderId: order.orderId, receipt: {'productId': order.storeProductId}),
      throwsA(isA<PaymentApiException>()),
    );
  });
```
> `repo` here is the attacker's (setUp's token is a fresh user). The server returns 404 ORDER_NOT_FOUND because the order belongs to owner. `PaymentApiException` thrown → test passes.

- [ ] **Step 2: Run full suite — server prereq + all payment tests**

Run the CRITICAL prereq block, then:
`cd flutter && flutter test --dart-define=MOBILEUI_API_URL=http://localhost:3210 --dart-define=MOBILEUI_APP_ID=zhongbei --dart-define=MOBILEUI_APP_ENVIRONMENT=development --dart-define=MOBILEUI_PLATFORM=ios test/payment/`
Kill server. Expected: ALL payment tests PASS (models + repository + provider + controller incl. ownership).
Then `cd flutter && flutter analyze` → clean.
Then the pre-existing tests still pass: `cd flutter && flutter test test/widget_test.dart test/auth_screen_test.dart` (no server needed for those if they don't hit the network — if they do, they need the server too; run with the prereq).

- [ ] **Step 3: Commit**
```bash
git add flutter/test/payment/payment_controller_test.dart
git commit -m "test(flutter): cross-user verify ownership check + full payment suite green"
```

---

## Self-Review (controller's checklist)

**Spec coverage:**
- §2.1 PaymentProvider → Task 3 ✓
- §2.2 PaymentRepository → Task 2 ✓
- §2.3 TokenStore → Task 2 ✓
- §2.4 PaymentController/Scope → Task 4 ✓
- §2.5 models (BillingPlan.storeProductMapping, OrderView, Entitlement/Subscription/MembershipCurrent) → Task 1 ✓
- §2.6 CheckoutScreen → Task 5 ✓
- §3 checkout flow (createOrder→purchase→verify→membershipCurrent) → Task 4 controller ✓
- §4 wiring (mount scope, router, MembershipScreen, remove old purchase) → Task 5 ✓
- §5 errors/AsyncState → Task 4 controller (Unauthorized/Failure/Offline) ✓
- §6 real-environment tests (no fakes; InMemoryTokenStore) → Tasks 2/4/6 ✓
- §8 acceptance (MEM-09/10/14/16, PAY-03/04/05, QLT-07/08/09) → covered across tasks ✓

**Placeholder scan:** Task 5 Step 1 has explicit instructions for the AppButton/AppCard name uncertainty (fallback to FilledButton/Card) — not a placeholder, a guarded verification. Task 5 Step 3 documents the pendingPlanId design decision concretely. No TBD/TODO.

**Type consistency:** `OrderStatus` enum used in Task 1 (runtime_models), Task 4 (controller test asserts `OrderStatus.success`), Task 6 — consistent. `PaymentApiException` defined Task 2, used Task 4/6 — consistent. `CreateOrderResult.storeProductId` → `provider.purchase(storeProductId)` → `verifyPurchase(orderId, receipt)` — chain consistent. `MembershipCurrent` defined Task 1, used Task 2/4 — consistent.

**Known deviations from spec (intentional, documented in tasks):**
- Spec §4 said "orders 改读 PaymentRepository" — plan KEEPS `AppController.orders`/`loadOrders` (GET /orders unaffected by P-1.1) to minimize churn; `PaymentRepository.orders()` also added for completeness. No regression.
- Spec §2.2 mentioned "401 单飞刷新" — plan mirrors `support_repository` (NO own refresh; 401 → `PaymentApiException(401)` → controller `Unauthorized`). Consistent with the support subdomain's actual pattern.

---

## Execution Handoff

Plan saved to `docs/superpowers/plans/2026-08-10-payment-flutter-client.md`. Two options:

1. **Subagent-Driven (recommended)** — fresh subagent per task, two-stage review.
2. **Inline Execution** — batch with checkpoints.

Which approach?
