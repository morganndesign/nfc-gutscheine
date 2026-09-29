<!doctype html>
<html lang="{{ $lang === 'bs' ? 'bs' : $lang }}">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex, nofollow">
    <title>{{ $restaurant ?? $copy['title'] }}</title>
    <style>
        :root { color-scheme: light dark; --ink: #18181b; --muted: #71717a; --bg: #f4f4f5; --card: #fff; }
        @media (prefers-color-scheme: dark) { :root { --ink: #fafafa; --muted: #a1a1aa; --bg: #09090b; --card: #18181b; } }
        * { box-sizing: border-box; }
        body { margin: 0; min-height: 100vh; display: grid; place-items: center; padding: 16px; background: var(--bg);
               color: var(--ink); font: 16px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
        main { width: 100%; max-width: 380px; border-radius: 20px; overflow: hidden; background: var(--card);
               box-shadow: 0 1px 3px rgb(0 0 0 / .08); }
        header { padding: 20px 24px; color: #fff; background: {{ $brand }}; }
        header p { margin: 0; font-size: 12px; letter-spacing: .12em; text-transform: uppercase; opacity: .8; }
        header h1 { margin: 4px 0 0; font-size: 22px; font-weight: 600; }
        section { padding: 28px 24px; text-align: center; }
        .label { margin: 0; color: var(--muted); font-size: 14px; }
        .amount { margin: 4px 0 8px; font-size: 44px; font-weight: 600; letter-spacing: -.02em; font-variant-numeric: tabular-nums; }
        .muted { margin: 0; color: var(--muted); font-size: 14px; }
        .message { margin: 0; font-size: 17px; }
    </style>
</head>
<body>
<main>
    <header>
        <p>{{ $copy['title'] }}</p>
        @if ($restaurant)<h1>{{ $restaurant }}</h1>@endif
    </header>
    <section>
        @if ($balance)
            <p class="label">{{ $copy['balance'] }}</p>
            <p class="amount">{{ $balance['balance'] }}</p>
            <p class="muted">{{ $balance['validity'] }}</p>
            <p class="muted" style="margin-top:16px">{{ $copy['pay'] }}</p>
        @else
            <p class="message">{{ $message }}</p>
        @endif
    </section>
</main>
</body>
</html>
