<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Center extends Model
{
    protected $fillable = ['name', 'code', 'phone', 'address'];

    public function matchings(): HasMany
    {
        return $this->hasMany(Matching::class);
    }

    public function admins(): HasMany
    {
        return $this->hasMany(Admin::class);
    }

    /** N:M 소속 보호사 (center_user_affiliation) */
    public function affiliatedUsers(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'center_user_affiliation', 'center_id', 'user_id', 'id', 'user_id');
    }

    public function clients(): HasMany
    {
        return $this->hasMany(Client::class, 'center_id');
    }

    /** 센터별 운영 설정 1건 (바우처 단가 등). */
    public function setting(): \Illuminate\Database\Eloquent\Relations\HasOne
    {
        return $this->hasOne(CenterSetting::class, 'center_id');
    }

    /** 센터 내부 공지사항. */
    public function notices(): HasMany
    {
        return $this->hasMany(Notice::class, 'center_id');
    }
}
