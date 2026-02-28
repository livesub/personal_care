<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\HasApiTokens;

/**
 * 관리자 계정. Sanctum tokenable (tokenable_type = App\Models\Admin).
 * admins 테이블. login_id, password 저장 시 소문자 변환.
 * 비밀번호: hashed 캐스트 미사용(로드 시 드라이버 검증 제거). 저장 시에만 Argon2id 명시.
 */
class Admin extends Authenticatable
{
    use HasApiTokens;

    protected $fillable = [
        'center_id',
        'login_id',
        'password',
        'name',
        'email',
        'status',
        'role',
        'is_temp_account',
    ];

    protected $hidden = ['password'];

    protected function casts(): array
    {
        return [
            'is_temp_account' => 'boolean',
        ];
    }

    /** 로그인 ID 저장 시 소문자 변환 */
    protected function loginId(): Attribute
    {
        return Attribute::make(
            set: fn (string $value) => strtolower($value),
        );
    }

    /** 비밀번호: 평문이면 소문자 후 Argon2id 해시. 이미 해시($로 시작)면 그대로(DB 로드 시 검증 없음). */
    protected function password(): Attribute
    {
        return Attribute::make(
            set: function (string $value) {
                if (str_starts_with($value, '$')) {
                    return $value;
                }
                return Hash::driver('argon2id')->make(strtolower($value));
            },
        );
    }

    public function center(): \Illuminate\Database\Eloquent\Relations\BelongsTo
    {
        return $this->belongsTo(Center::class);
    }
}
