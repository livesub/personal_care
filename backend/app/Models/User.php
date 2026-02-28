<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

/**
 * 보호사(활동지원사) 계정 모델.
 * 기획서: 1_AI 로그인.pdf, users 테이블.
 */
class User extends Authenticatable
{
    /** @use HasFactory<\Database\Factories\UserFactory> */
    use HasFactory, Notifiable, HasApiTokens;

    protected $table = 'users';

    /** PK: 기획서 기준 user_id */
    protected $primaryKey = 'user_id';

    public $incrementing = true;

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'login_id',
        'password',
        'name',
        'email',
        'resident_no_prefix',
        'resident_no_suffix_hidden',
        'status',
        'is_first_login',
        'identity_cancel_count',
        'default_hourly_wage',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'resident_no_prefix',
        'resident_no_suffix_hidden',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    /**
     * Casts.
     * resident_no_suffix_hidden: encrypted → APP_KEY로 AES-256 암복호화. APP_KEY를 바꾸면 기존 저장값 복호화 불가(에러 또는 깨진 문자열).
     */
    protected function casts(): array
    {
        return [
            'password' => 'hashed', // Argon2id (config: hashing.driver)
            'resident_no_prefix' => 'encrypted', // AES-256-CBC, APP_KEY
            'resident_no_suffix_hidden' => 'encrypted',
            'is_first_login' => 'boolean',
            'identity_cancel_count' => 'integer',
        ];
    }

    /**
     * login_id: DB 저장 시 하이픈 제거 (기획서 - 숫자만 저장, 예: 01012345678).
     * 값을 바꾸면 기존 연락처 검색/알림 발송 로직과 불일치할 수 있음.
     */
    protected function loginId(): Attribute
    {
        return Attribute::make(
            set: fn (string $value) => preg_replace('/\D/', '', $value),
        );
    }

    public function matchings(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(\App\Models\Matching::class, 'user_id', 'user_id');
    }

    /** N:M 소속 센터 (center_user_affiliation) */
    public function affiliatedCenters(): \Illuminate\Database\Eloquent\Relations\BelongsToMany
    {
        return $this->belongsToMany(
            \App\Models\Center::class,
            'center_user_affiliation',
            'user_id',
            'center_id',
            'user_id',
            'id'
        );
    }
}
