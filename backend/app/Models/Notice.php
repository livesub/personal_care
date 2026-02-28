<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * 센터 내부 공지사항 (운영 관리). 센터 전용 공지.
 * 데이터 격리: center_id 기준 Global Scope — 본인 센터 공지만 조회.
 */
class Notice extends Model
{
    protected $table = 'notices';

    protected $fillable = [
        'center_id',
        'title',
        'content',
    ];

    protected static function booted(): void
    {
        /** 데이터 격리: 본인 센터( current_center_id ) 공지만 조회 */
        static::addGlobalScope('center', function (Builder $builder): void {
            if (app()->bound('current_center_id') && app('current_center_id') !== null) {
                $builder->where('center_id', app('current_center_id'));
            }
        });
    }

    public function center(): BelongsTo
    {
        return $this->belongsTo(Center::class);
    }
}
