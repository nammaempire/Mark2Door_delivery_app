# mart2door — delivery app

Delivery partner app for Android, built with Flutter. Sits beside the
customer app (`../mart2door`) and the admin web (`../mart2door_admin`).

**Status: UI complete, running on sample data.** It is not connected to
Firebase yet, so orders here are examples and are not the ones placed in
the customer app or assigned in the admin.

## Run it

```bash
flutter pub get
flutter run
```

| What  | Sample-data value                |
| ----- | -------------------------------- |
| Login | any valid 10-digit mobile number |
| OTP   | `123456`                         |

Sample orders reset when the app restarts. Login and the online/offline
switch are remembered.

## Screens

Splash → Login → OTP → **Orders** (New / Active tabs, online switch,
today's totals) → Accept or Reject → **Pickup** (store address, item
checklist) → **Delivery** (route preview, call, navigate, cash to collect)
→ Mark delivered (cash confirmation) → **History** → **Profile**.

Rules built into the flow:

- Pickup cannot be confirmed until every item is ticked.
- A cash order cannot be marked delivered until the rider confirms the
  cash was collected.
- Going offline hides new orders; active deliveries stay visible.

## Map

The route on the Delivery screen is an **illustration**, not live map
tiles (`route_map.dart`). The **Navigate** button already opens real
turn-by-turn directions in Google Maps, and **Call** opens the dialer.

To show a live in-app map, add the `google_maps_flutter` package and a
Google Maps API key (Google Cloud project with billing enabled), then
replace `RouteMap` with a `GoogleMap` widget. Real distances also need
customer coordinates saved on each order.

## Project structure

```
lib/
  main.dart, app.dart
  core/       config, providers (composition root), router, theme, utils
  features/
    auth/     phone + OTP sign-in (same screens as the customer app)
    orders/   domain model, repository interface + sample data,
              orders list, pickup, delivery, route map
    history/  delivered orders and cash to hand over
    profile/  availability, pickup point, log out
test/
  delivery_flow_test.dart   end-to-end journeys on sample data
```

## Connecting to Firebase (next step)

`DeliveryRepository` is the only thing to implement:

- `watchOrders()` → `orders` where `riderId == <this rider>`.
- `accept` / `confirmPickup` / `markDelivered` → set `status` to
  `accepted` / `pickedUp` / `delivered`.
- `reject` → clear `riderId`, `riderName`, `riderPhone` so the admin can
  reassign.

Riders are matched to the `riders` collection by phone number. Then swap
the two providers in `lib/core/providers.dart`.

## Tests

```bash
flutter test
```
# Mark2Door_delivery_app
