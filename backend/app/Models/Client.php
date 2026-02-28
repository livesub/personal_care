<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Facades\Crypt;

/**
 * 장애인 이용자(관리 대상).
 * - 저장 시: resident_no_suffix → AES-256 암호화 + SHA-256 해시 동시 설정 (Mutator).
 * - API 응답 시: resident_no_suffix_hidden은 Accessor로 복호화된 값이 JSON에 포함됨 (Flutter 화면 표시용).
 * - 데이터 격리: current_center_id가 설정된 요청에서만 해당 center_id 데이터 조회 (Global Scope).
 */
class Client extends Model
{
    use HasFactory;

    protected $table = 'clients';

    protected $fillable = [
        'center_id',
        'name',
        'phone',
        'resident_no_prefix',
        'resident_no_suffix_hidden',
        'resident_no_suffix_hash',
        'gender',
        'disability_type',
        'grade',
        'voucher_balance',
        'status',
        'home_lat',
        'home_lng',
    ];

    /** SHA-256 해시는 API에 노출하지 않음. hidden만 제거 시 Accessor가 복호화값을 JSON으로 반환 */
    protected $hidden = [
        'resident_no_suffix_hash',
    ];

    protected static function booted(): void
    {
        /** 데이터 격리: 로그인한 관리자/보호사의 center_id에 해당하는 데이터만 조회 */
        static::addGlobalScope('center', function (Builder $builder): void {
            if (app()->bound('current_center_id') && app('current_center_id') !== null) {
                $builder->where('center_id', app('current_center_id'));
            }
        });
    }

    protected function casts(): array
    {
        return [
            'voucher_balance' => 'decimal:0',
        ];
    }

    /**
     * 주민번호 뒷자리: 저장 시 AES-256 암호화 + SHA-256 해시(검색용) 동시 설정.
     */
    public function setResidentNoSuffixHiddenAttribute(?string $value): void
    {
        $plain = $value ?? '';
        $this->attributes['resident_no_suffix_hash'] = $plain !== '' ? hash('sha256', $plain) : '';
        $this->attributes['resident_no_suffix_hidden'] = $plain !== '' ? Crypt::encryptString($plain) : '';
    }

    /**
     * 주민번호 뒷자리 복호화 조회.
     * API 응답(JSON) 시 Flutter로 복호화된 값이 전달되어 화면에 표시됨.
     */
    public function getResidentNoSuffixHiddenAttribute(?string $value): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }
        try {
            return Crypt::decryptString($value);
        } catch (\Throwable) {
            return null;
        }
    }

    public function center(): BelongsTo
    {
        return $this->belongsTo(Center::class, 'center_id');
    }

    public function emergencyContacts(): HasMany
    {
        return $this->hasMany(ClientEmergencyContact::class, 'client_id');
    }
}
