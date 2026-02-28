<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Holiday extends Model
{
    protected $table = 'holidays';

    protected $fillable = ['date', 'name'];

    protected function casts(): array
    {
        return ['date' => 'date'];
    }

    public static function isHoliday(\DateTimeInterface $date): bool
    {
        $dateStr = $date->format('Y-m-d');
        return self::where('date', $dateStr)->exists();
    }
}
