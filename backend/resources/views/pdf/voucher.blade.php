<!DOCTYPE html>
<html lang="{{ $language }}">
<head>
<meta charset="utf-8">
<style>
    /* A5 (148 × 210 mm): the voucher as a real card (ID-1, 85.6 × 54 mm, here at 120 × 75.7 mm) on a letter. */
    @page { margin: 0; }
    * { box-sizing: border-box; }
    body { margin: 0; font-family: 'DejaVu Sans', sans-serif; color: #1a1a1a; background: #ffffff; }
    .sheet { padding: 16mm 14mm 0; }

    .card { position: relative; width: 120mm; height: 75.7mm; margin: 0 auto; border-radius: 4.5mm; background: {{ $brand }}; color: {{ $ink }}; overflow: hidden; }
    .ring { position: absolute; border-radius: 50%; border: 0.35mm solid {{ $accent }}; }
    .ring.one { width: 88mm; height: 88mm; right: -40mm; top: -44mm; opacity: 0.30; }
    .ring.two { width: 60mm; height: 60mm; right: -26mm; top: -30mm; opacity: 0.22; }
    .brand { position: absolute; left: 8mm; top: 7mm; font-size: 11pt; font-weight: bold; letter-spacing: 0.2pt; }
    .brand img { max-height: 11mm; max-width: 48mm; }
    .kind { position: absolute; right: 8mm; top: 8.2mm; font-size: 6.5pt; letter-spacing: 2.6pt; text-transform: uppercase; font-weight: bold; color: {{ $accent }}; }
    .for { position: absolute; left: 8mm; bottom: 27mm; font-family: 'DejaVu Serif', serif; font-style: italic; font-size: 10.5pt; }
    .label { position: absolute; left: 8mm; bottom: 20.5mm; font-size: 6pt; letter-spacing: 2.4pt; text-transform: uppercase; font-weight: bold; color: {{ $accent }}; }
    .value { position: absolute; left: 7.4mm; bottom: 6.5mm; font-size: 30pt; font-weight: bold; letter-spacing: -0.4pt; line-height: 1; }

    .note { width: 112mm; margin: 14mm auto 0; text-align: center; }
    .headline { font-family: 'DejaVu Serif', serif; font-style: italic; font-size: 17pt; line-height: 1.2; color: #1a1a1a; }
    .message { margin-top: 4mm; font-family: 'DejaVu Serif', serif; font-size: 10.5pt; line-height: 1.55; color: #333333; }
    .message.personal { font-style: italic; font-size: 11.5pt; color: #1a1a1a; }

    .divider { width: 24mm; margin: 11mm auto 0; border-top: 0.3mm solid {{ $rule }}; }

    .redeem { width: 120mm; margin: 11mm auto 0; border-collapse: collapse; }
    .redeem td { vertical-align: middle; padding: 0; }
    .qr { width: 34mm; height: 34mm; display: block; }
    .info { padding-left: 9mm; }
    .how { font-size: 9.5pt; font-weight: bold; line-height: 1.35; }
    .fine { margin-top: 2mm; font-size: 7pt; line-height: 1.45; color: #6b6b6b; }

    .footer { position: absolute; left: 0; right: 0; bottom: 9mm; text-align: center; font-size: 7pt; letter-spacing: 1.6pt; text-transform: uppercase; color: #9a9a9a; }
</style>
</head>
<body>
<div class="sheet">
    <div class="card">
        <div class="ring one"></div>
        <div class="ring two"></div>
        <div class="brand">@if ($logo)<img src="{{ $logo }}" alt="{{ $restaurantName }}">@else{{ $restaurantName }}@endif</div>
        <div class="kind">{{ $copy['voucher'] }}</div>
        @if ($recipient)<div class="for">{{ $copy['for'] }} {{ $recipient }}</div>@endif
        <div class="label">{{ $copy['value'] }}</div>
        <div class="value">{{ $value }}</div>
    </div>

    <div class="note">
        <div class="headline">{{ $headline }}</div>
        @if ($message)<div class="message{{ $personal ? ' personal' : '' }}">{{ $personal ? $copy['open'].$message.$copy['close'] : $message }}</div>@endif
    </div>

    <div class="divider"></div>

    <table class="redeem">
        <tr>
            <td style="width: 34mm;"><img class="qr" src="{{ $qr }}" alt="QR"></td>
            <td class="info">
                <div class="how">{{ $copy['howTo'] }}</div>
                <div class="fine">{{ $validity }}</div>
                <div class="fine">{{ $copy['keepSafe'] }}</div>
            </td>
        </tr>
    </table>
</div>
<div class="footer">{{ $restaurantName }}</div>
</body>
</html>
