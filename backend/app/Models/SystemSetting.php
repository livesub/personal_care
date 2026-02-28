<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Cache;

class SystemSetting extends Model
{
    protected $table = 'system_settings';

    protected $fillable = ['key', 'value'];

    public static function getValue(string $key, mixed $default = null): mixed
    {
        $cacheKey = 'system_setting:' . $key;
        return Cache::remember($cacheKey, 3600, function () use ($key, $default) {
            $row = self::where('key', $key)->first();
            return $row ? $row->value : $default;
        });
    }

    public static function setValue(string $key, mixed $value): void
    {
        self::updateOrCreate(
            ['key' => $key],
            ['value' => (string) $value]
        );
        Cache::forget('system_setting:' . $key);
    }

    public static function getDefaultHourlyWage(): int
    {
        $v = self::getValue('default_hourly_wage', 16150);
        return (int) $v;
    }
}
