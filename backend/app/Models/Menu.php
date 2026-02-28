<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * 관리자 메뉴 마스터.
 * role(staff)인 경우 is_staff_accessible=false 메뉴 접근 불가.
 */
class Menu extends Model
{
    protected $fillable = [
        'name',
        'route_name',
        'icon',
        'is_staff_accessible',
    ];

    protected function casts(): array
    {
        return [
            'is_staff_accessible' => 'boolean',
        ];
    }
}
