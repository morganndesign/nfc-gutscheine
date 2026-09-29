<?php

declare(strict_types=1);

namespace App\Crypto\Ntag424;

use App\Crypto\Primitives\Aes;
use App\Crypto\Primitives\Cmac;
use InvalidArgumentException;

/**
 * EV2 secure messaging after AuthenticateEV2First (NT4H2421Gx §9.1, NXP AN12196 §4): the server builds every
 * command of an authenticated session, the phone only relays it.
 *
 * - CommMode.MAC: `Cmd ‖ CmdCtr ‖ TI ‖ header ‖ data` is MACed with SesAuthMACKey, truncated to the odd bytes.
 * - CommMode.Full: the data is padded (80 00…, always) and encrypted with SesAuthENCKey under
 *   IV = E(SesAuthENCKey, A5 5A ‖ TI ‖ CmdCtr ‖ 0…), then MACed like CommMode.MAC.
 * - Every response of the session carries `MAC(00 ‖ CmdCtr+1 ‖ TI ‖ data)`; the counter moves on with every
 *   command/response pair.
 *
 * The counter is the only state; {@see self::counter()} and {@see self::resume()} carry it between the phone's
 * round trips.
 */
final class SecureMessaging
{
    private function __construct(
        private readonly Ev2Session $session,
        private int $counter,
    ) {}

    public static function start(Ev2Session $session): self
    {
        return new self($session, 0);
    }

    public static function resume(Ev2Session $session, int $counter): self
    {
        if ($counter < 0 || $counter > 0xFFFF) {
            throw new InvalidArgumentException('The command counter is 16 bits.');
        }

        return new self($session, $counter);
    }

    public function counter(): int
    {
        return $this->counter;
    }

    /** A CommMode.MAC command: `90 Cmd 00 00 Lc header ‖ MACt 00`. */
    public function macCommand(int $cmd, string $header, string $data = ''): string
    {
        $mac = $this->mac(chr($cmd).$this->counterBytes().$this->session->transactionId.$header.$data);

        return self::apdu($cmd, $header.$data.$mac);
    }

    /** A CommMode.Full command: `90 Cmd 00 00 Lc header ‖ E(data ‖ 80 00…) ‖ MACt 00`. */
    public function fullCommand(int $cmd, string $header, string $data): string
    {
        $iv = Aes::encryptBlock($this->session->encryptionKey, "\xA5\x5A".$this->session->transactionId.$this->counterBytes().str_repeat("\0", 8));
        $encrypted = Aes::encryptCbc($this->session->encryptionKey, $iv, self::pad($data));
        $mac = $this->mac(chr($cmd).$this->counterBytes().$this->session->transactionId.$header.$encrypted);

        return self::apdu($cmd, $header.$encrypted.$mac);
    }

    /**
     * Checks the card's answer to the command just built and moves the counter on. Returns the response data
     * (plain; CommMode.MAC) without MAC and status word, or null when the card refused or the MAC is wrong.
     *
     * @param  bool  $macked  false only for the one answer without MAC: ChangeKey of the authenticated key
     */
    public function response(string $response, bool $macked = true): ?string
    {
        if (strlen($response) < 2 || substr($response, -2) !== "\x91\x00") {
            return null;
        }
        $this->counter++;
        if (! $macked) {
            return strlen($response) === 2 ? '' : null;
        }
        if (strlen($response) < 10) {
            return null;
        }
        $data = substr($response, 0, -10);
        $mac = substr($response, -10, 8);

        return hash_equals($this->mac("\x00".$this->counterBytes().$this->session->transactionId.$data), $mac) ? $data : null;
    }

    /** ISO 7816-4 wrapped native command: `90 Cmd 00 00 Lc data 00` (or `90 Cmd 00 00 00` without data). */
    public static function apdu(int $cmd, string $data = ''): string
    {
        if (strlen($data) > 255) {
            throw new InvalidArgumentException('A short APDU carries at most 255 bytes.');
        }

        return $data === ''
            ? "\x90".chr($cmd)."\x00\x00\x00"
            : "\x90".chr($cmd)."\x00\x00".chr(strlen($data)).$data."\x00";
    }

    /** ISO/IEC 9797-1 padding method 2, always applied. */
    public static function pad(string $data): string
    {
        $padded = $data."\x80";

        return str_pad($padded, (int) (ceil(strlen($padded) / Aes::BLOCK) * Aes::BLOCK), "\0");
    }

    /** CMAC truncated to bytes 1, 3, …, 15. */
    public static function truncatedMac(string $key, string $message): string
    {
        $full = Cmac::compute($key, $message);
        $out = '';
        for ($i = 1; $i < 16; $i += 2) {
            $out .= $full[$i];
        }

        return $out;
    }

    private function mac(string $message): string
    {
        return self::truncatedMac($this->session->macKey, $message);
    }

    private function counterBytes(): string
    {
        return pack('v', $this->counter);
    }
}
