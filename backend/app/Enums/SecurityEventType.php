<?php

declare(strict_types=1);

namespace App\Enums;

/**
 * The catalogue of security events (ADR-003). One case per security-sensitive action; the outcome
 * ({@see SecurityEventOutcome}) says whether it happened or was refused, `reason` says why it was refused.
 *
 * Each type declares the keys its `data` may carry, so the stream stays a stable schema for dashboards,
 * analytics and model training. Changing the meaning of a key means a new key (or a new type), never a
 * reinterpretation of stored events; `schema_version` on every row marks the catalogue version it was written
 * under.
 *
 * Card types (activate, bind, replace, tap, challenge) are added with the card phases.
 */
enum SecurityEventType: string
{
    // Authentication ------------------------------------------------------------------------------------------
    /** E-mail + password sign-in, web or app. Refused: `invalid_credentials`, `account_locked`, `account_deactivated`, `restaurant_suspended`. */
    case SignIn = 'auth.sign_in';
    /** Too many sign-in requests from one address or for one account (rate limiter). */
    case SignInThrottle = 'auth.sign_in_throttle';
    /** An account is locked after repeated wrong passwords. */
    case AccountLock = 'auth.account_lock';
    case SignOut = 'auth.sign_out';
    /** A device-bound app token was issued. */
    case DeviceTokenIssue = 'auth.device_token_issue';
    /** An app token was used for something it may not do, or from another device (always refused). */
    case DeviceTokenUse = 'auth.device_token_use';
    /** All sessions and tokens of a user were revoked (password change, deactivation, role change). */
    case AccessRevoke = 'auth.access_revoke';
    case PasswordChange = 'auth.password_change';
    case PasswordResetRequest = 'auth.password_reset_request';
    /** A password was set from a reset or invitation link. Refused: `invalid_token`. */
    case PasswordReset = 'auth.password_reset';

    // Staff, devices, integrations ------------------------------------------------------------------------------
    case StaffCreate = 'staff.create';
    /** Role or status of a staff member changed. */
    case StaffChange = 'staff.change';
    case StaffDeactivate = 'staff.deactivate';
    case StaffActivate = 'staff.activate';
    case DeviceRegister = 'device.register';
    case DeviceRevoke = 'device.revoke';
    case DeviceRestore = 'device.restore';
    case IntegrationTokenCreate = 'integration.token_create';
    case IntegrationTokenRevoke = 'integration.token_revoke';

    // Vouchers -------------------------------------------------------------------------------------------------
    /** A voucher QR was scanned (presentment). Refused: `not_recognized`, `method_not_allowed`, `throttled`, … */
    case VoucherScan = 'voucher.scan';
    /** A voucher was sold. Refused with the sale's error code. */
    case VoucherIssue = 'voucher.issue';
    case VoucherReload = 'voucher.reload';
    case VoucherRedeem = 'voucher.redeem';
    /** A ledger entry was corrected by a reversal. */
    case VoucherReverse = 'voucher.reverse';
    case VoucherBlock = 'voucher.block';
    case VoucherUnblock = 'voucher.unblock';
    case VoucherExpire = 'voucher.expire';
    case VoucherReinstate = 'voucher.reinstate';
    /** A spending medium (printable QR) was issued or revoked. */
    case MediumIssue = 'voucher.medium_issue';
    case MediumRevoke = 'voucher.medium_revoke';

    // Physical cards -------------------------------------------------------------------------------------------
    /** A card entered the system or changed its lifecycle state (register, activate, bind, replace, revoke, …). */
    case CardTransition = 'card.transition';
    /** A card was tapped and its SUN message checked (guest balance page). Refused: SUN_VERIFICATION_FAILED, SUN_REPLAYED, … */
    case CardTap = 'card.tap';
    /** A card batch changed its status (and moved its cards). */
    case CardBatchStatus = 'card.batch_status';

    // Platform -------------------------------------------------------------------------------------------------
    case RestaurantSuspend = 'platform.restaurant_suspend';
    case RestaurantReactivate = 'platform.restaurant_reactivate';

    /**
     * The keys `data` may carry for this type. Anything else is a programming error.
     *
     * @return list<string>
     */
    public function dataKeys(): array
    {
        return match ($this) {
            self::SignIn => ['channel', 'email_hash', 'attempts'],
            self::SignInThrottle => ['channel', 'email_hash', 'retry_after'],
            self::AccountLock => ['attempts', 'minutes'],
            self::SignOut => ['channel'],
            self::DeviceTokenIssue => ['platform', 'abilities'],
            self::DeviceTokenUse => ['method', 'route'],
            self::AccessRevoke => ['cause', 'tokens'],
            self::PasswordChange, self::PasswordResetRequest => [],
            self::PasswordReset => ['purpose', 'email_hash'],
            self::StaffCreate => ['role'],
            self::StaffChange => ['role', 'previous_role', 'fields'],
            self::StaffDeactivate, self::StaffActivate => [],
            self::DeviceRegister => ['platform'],
            self::DeviceRevoke, self::DeviceRestore => [],
            self::IntegrationTokenCreate => ['abilities'],
            self::IntegrationTokenRevoke => [],
            self::VoucherScan => ['method', 'purpose', 'presentment_id'],
            self::VoucherIssue => ['kind', 'payment_method', 'replayed', 'transaction_id', 'with_customer'],
            self::VoucherReload => ['payment_method', 'replayed', 'transaction_id'],
            self::VoucherRedeem => ['replayed', 'transaction_id', 'presentment_id', 'balance_after'],
            self::VoucherReverse => ['transaction_id', 'reversed_transaction_id', 'reversed_type'],
            self::VoucherBlock, self::VoucherExpire, self::VoucherReinstate => ['previous_status'],
            self::VoucherUnblock => [],
            self::MediumIssue => ['medium_type', 'cause'],
            self::MediumRevoke => ['medium_type', 'cause'],
            self::CardTransition => ['card_number', 'from_state', 'to_state', 'cause', 'batch_code'],
            self::CardTap => ['key_set', 'card_number', 'counter', 'purpose'],
            self::CardBatchStatus => ['batch_code', 'from_status', 'to_status', 'cards_moved'],
            self::RestaurantSuspend, self::RestaurantReactivate => [],
        };
    }
}
