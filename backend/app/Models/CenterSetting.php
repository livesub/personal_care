<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\Schema;

/**
 * 센터별 운영 설정 (운영 관리). 바우처 단가 등.
 * 데이터 격리: 조회 시 로그인한 관리자의 center_id 데이터만. Global Scope 적용.
 */
class CenterSetting extends Model
{
    protected $table = 'center_settings';

    protected $fillable = [
        'center_id',
        'voucher_unit_price',
    ];

    protected function casts(): array
    {
        return [
            'voucher_unit_price' => 'integer',
        ];
    }

    protected static function booted(): void
    {
        /** 데이터 격리: 본인 센터( current_center_id ) 설정만 조회 */
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

    /**
     * 센터별 바우처 시간당 단가(원). 테이블/레코드 없으면 기본값 16150.
     */
    public static function getVoucherUnitPriceForCenter(int $centerId): int
    {
        if (! Schema::hasTable('center_settings')) {
            return 16150;
        }
        try {
            $row = self::withoutGlobalScope('center')
                ->where('center_id', $centerId)
                ->first();
            return $row ? (int) $row->voucher_unit_price : 16150;
        } catch (\Throwable) {
            return 16150;
        }
    }
}
