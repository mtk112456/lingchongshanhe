<?php
declare(strict_types=1);

final class Clock
{
    private DateTimeZone $tz;

    public function __construct(string $timezone = 'Asia/Shanghai')
    {
        $this->tz = new DateTimeZone($timezone);
    }

    public function now(): DateTimeImmutable
    {
        return new DateTimeImmutable('now', $this->tz);
    }

    public function sql(): string
    {
        return $this->now()->format('Y-m-d H:i:s');
    }

    public function fromSql(string $value): DateTimeImmutable
    {
        return new DateTimeImmutable($value, $this->tz);
    }

    /**
     * 4 周赛季：每 7 个回合一周，回合 1–7 = 第 1 周。
     */
    public static function weekOfTurn(int $turnNo, int $turnsPerWeek = 7): int
    {
        return intdiv(max(1, $turnNo) - 1, max(1, $turnsPerWeek)) + 1;
    }
}
