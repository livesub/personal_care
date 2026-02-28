<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * 매칭(배정). 데이터 격리는 컨트롤러에서 current_center_id로 where('center_id', $centerId) 적용.
 * (Global Scope 미사용: 쿼리 조건 꼬임 방지)
 */
class Matching extends Model
{
    protected $fillable = [
        'user_id', 'helper_id', 'center_id', 'client_id',
        'start_at', 'end_at', 'real_end_time', 'early_stop_reason',
        'status', 'actual_start_time',
        'work_log', 'early_end_reason',
        'hourly_wage',
        'check_in_lat', 'check_in_lng', 'check_out_lat', 'check_out_lng',
    ];

    protected function casts(): array
    {
        return [
            'start_at' => 'datetime',
            'end_at' => 'datetime',
            'real_end_time' => 'datetime',
            'actual_start_time' => 'datetime',
            'hourly_wage' => 'integer',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id', 'user_id');
    }

    public function center(): BelongsTo
    {
        return $this->belongsTo(Center::class);
    }

    public function client(): BelongsTo
    {
        return $this->belongsTo(Client::class);
    }
}
