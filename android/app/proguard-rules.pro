# R8 keep rules for release minification.
# Generated from build/app/outputs/mapping/release/missing_rules.txt after
# flutter_secure_storage pulled in Google Tink, which references compile-time
# annotations that are not on the runtime classpath.
-dontwarn com.google.errorprone.annotations.CanIgnoreReturnValue
-dontwarn com.google.errorprone.annotations.CheckReturnValue
-dontwarn com.google.errorprone.annotations.Immutable
-dontwarn com.google.errorprone.annotations.RestrictedApi
-dontwarn javax.annotation.Nullable
-dontwarn javax.annotation.concurrent.GuardedBy
