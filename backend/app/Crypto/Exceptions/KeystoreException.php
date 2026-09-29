<?php

declare(strict_types=1);

namespace App\Crypto\Exceptions;

use RuntimeException;

/** The keystore is missing, unreadable, tampered with, or its master key is absent or wrong. Fails closed. */
final class KeystoreException extends RuntimeException {}
