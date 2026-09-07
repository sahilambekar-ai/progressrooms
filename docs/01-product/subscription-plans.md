# ProgressRooms Subscription Plans & Entitlement Architecture

## 1. Tiers and Pricing Matrix

| Tier | Plan Name | Status | Price (INR/mo) | Trial Period | Target Customer |
|------|-----------|--------|----------------|--------------|-----------------|
| Free | **Starter** | Active | ₹0 | 30 Days | New independent teachers testing the platform |
| Basic | **Core** | Active | ₹1,499 | None | Solo teachers running scheduled classes |
| Advanced | **Studio** | Active | ₹3,999 | None | Multi-teacher studios, academies & organizations |
| AI | **Progress AI** | Coming Soon | TBD | None | Advanced AI-assisted studio operations |

## 2. Feature Entitlements Model

Plans are not hardcoded. All limits and capabilities are resolved via the `plan_features` table and `FeatureEntitlementService`.

```text
Plan
 └── PlanFeature (feature_key, feature_value)
```

### Feature Keys

| Feature Key | Type | Starter | Core | Studio | Progress AI |
|-------------|------|---------|------|--------|-------------|
| `max_teachers` | Integer | 1 | 1 | 10 | 25 |
| `max_active_sessions` | Integer | 3 | 10 | Unlimited (-1) | Unlimited (-1) |
| `max_students` | Integer | 50 | 250 | Unlimited (-1) | Unlimited (-1) |
| `website_access` | Boolean | true (Default) | true (Default) | true | true |
| `advanced_website` | Boolean | false | false | true (3 templates) | true |
| `custom_domain` | Boolean | false | false | true | true |
| `zoom_integration` | Boolean | true | true | true | true |
| `analytics_access` | Boolean | Basic | Standard | Advanced | AI Predictive |
| `ai_features` | Boolean | false | false | false | true (Coming Soon) |

## 3. Subscription Statuses

- `TRIAL`: 30-day initial trial granted to new organizations.
- `ACTIVE`: Active paid recurring subscription.
- `PAST_DUE`: Payment renewal failed; 3-day grace period.
- `EXPIRED`: Trial ended or subscription lapsed without payment.
- `CANCELLED`: Subscription cancelled by owner; access remains until end of billing cycle.
- `SUSPENDED`: Suspended by Super Admin.
