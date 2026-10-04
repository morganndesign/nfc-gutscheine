<!DOCTYPE html>
<html lang="{{ $language }}">
<head>
<meta charset="utf-8">
<style>
    @page { margin: 0; }
    * { box-sizing: border-box; }
    body { margin: 0; font-family: 'DejaVu Sans', sans-serif; color: #141414; background: #ffffff; }
    .page { padding: 9mm 8mm 7mm; }
    .top { width: 100%; border-collapse: collapse; }
    .top td { vertical-align: middle; padding: 0; }
    .brand { font-size: 15pt; font-weight: bold; }
    .brand img { max-height: 16mm; max-width: 55mm; }
    .kind { text-align: right; font-size: 7.5pt; letter-spacing: 3pt; text-transform: uppercase; font-weight: bold; color: {{ $rule }}; }
    .band { width: 100%; margin-top: 6mm; border-collapse: separate; }
    .band td { background: {{ $brand }}; color: {{ $ink }}; border-radius: 4mm; padding: 9mm 8mm; height: {{ $bandHeight }}; vertical-align: top; }
    .headline { font-family: 'DejaVu Serif', serif; font-style: italic; font-size: 21pt; line-height: 1.15; }
    .recipient { margin-top: 2.5mm; font-size: 10.5pt; }
    .label { margin-top: 12mm; font-size: 7.5pt; letter-spacing: 2.6pt; text-transform: uppercase; font-weight: bold; color: {{ $accent }}; }
    .value { font-size: 36pt; font-weight: bold; line-height: 1.05; margin-top: 1mm; }
    .message { margin-top: 4mm; font-size: 9.5pt; line-height: 1.45; }
    .foot { width: 100%; margin-top: 7mm; border-collapse: collapse; }
    .foot td { vertical-align: middle; padding: 0; }
    .qr { width: 42mm; padding: 2mm; border: 0.6mm solid {{ $rule }}; border-radius: 2mm; background: #ffffff; }
    .qr img { width: 38mm; height: 38mm; display: block; }
    .info { padding-left: 6mm; }
    .how { font-size: 10pt; font-weight: bold; }
    .fine { margin-top: 2mm; font-size: 7.5pt; line-height: 1.4; color: #5b5b5b; }
    .name { margin-top: 2mm; font-size: 7.5pt; color: #8a8a8a; }
</style>
</head>
<body>
<div class="page">
    <table class="top">
        <tr>
            <td class="brand">@if ($logo)<img src="{{ $logo }}" alt="{{ $restaurantName }}">@else{{ $restaurantName }}@endif</td>
            <td class="kind">{{ $copy['voucher'] }}</td>
        </tr>
    </table>
    <table class="band"><tr><td>
        <div class="headline">{{ $headline }}</div>
        @if ($recipient)<div class="recipient">{{ $recipient }}</div>@endif
        <div class="label">{{ $copy['value'] }}</div>
        <div class="value">{{ $value }}</div>
        @if ($message)<div class="message">{{ $message }}</div>@endif
    </td></tr></table>
    <table class="foot">
        <tr>
            <td style="width: 42mm;"><div class="qr"><img src="{{ $qr }}" alt="QR"></div></td>
            <td class="info">
                <div class="how">{{ $copy['howTo'] }}</div>
                <div class="fine">{{ $validity }}</div>
                <div class="fine">{{ $copy['keepSafe'] }}</div>
                @if ($logo)<div class="name">{{ $restaurantName }}</div>@endif
            </td>
        </tr>
    </table>
</div>
</body>
</html>
