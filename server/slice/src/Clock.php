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
}
