<?php

namespace Database\Seeders;

use App\Models\Menu;
use Illuminate\Database\Seeder;

/**
 * 명세: 메뉴 4개 - 회원 관리, 매칭 관리, 모니터링, 설정.
 * '설정'만 is_staff_accessible = false (staff 접근 불가).
 */
class MenuSeeder extends Seeder
{
    public function run(): void
    {
        $rows = [
            ['name' => '회원 관리', 'route_name' => 'members', 'icon' => 'people', 'is_staff_accessible' => true],
            ['name' => '매칭 관리', 'route_name' => 'matchings', 'icon' => 'event_note', 'is_staff_accessible' => true],
            ['name' => '모니터링', 'route_name' => 'monitoring', 'icon' => 'monitor', 'is_staff_accessible' => true],
            ['name' => '설정', 'route_name' => 'settings', 'icon' => 'settings', 'is_staff_accessible' => false],
        ];
        foreach ($rows as $i => $row) {
            Menu::updateOrCreate(
                ['route_name' => $row['route_name']],
                [
                    'name' => $row['name'],
                    'icon' => $row['icon'],
                    'is_staff_accessible' => $row['is_staff_accessible'],
                ]
            );
        }
    }
}
