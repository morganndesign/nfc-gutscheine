<?php

declare(strict_types=1);

/*
|--------------------------------------------------------------------------
| Cross-Origin Resource Sharing
|--------------------------------------------------------------------------
| GiftCard Pro serves the web app and the API from the same origin, so browsers never
| need CORS. POS / accounting integrations call the API server-to-server with API
| tokens, which is not subject to CORS either. CORS is therefore disabled entirely:
| no Access-Control-* headers are ever emitted, so no third-party website can read
| API responses from a visitor's browser.
*/

return [
    'paths' => [],
    'allowed_methods' => [],
    'allowed_origins' => [],
    'allowed_origins_patterns' => [],
    'allowed_headers' => [],
    'exposed_headers' => [],
    'max_age' => 0,
    'supports_credentials' => false,
];
