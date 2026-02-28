<?php

namespace Database\Seeders;

use App\Models\Center;
use Illuminate\Database\Seeder;

/**
 * 명세: 센터 2개 - 의정부 센터(CODE: UJB), 양주 센터(CODE: YJU).
 * 일련번호 01 없음.
 */
class CenterSeeder extends Seeder
{
    public function run(): void
    {
        $rows = [
            [
                'code' => 'UJB',
                'name' => '의정부 센터',
                'phone' => null,
                'address' => null,
            ],
            [
                'code' => 'YJU',
                'name' => '양주 센터',
                'phone' => null,
                'address' => null,
            ],
        ];
        foreach ($rows as $row) {
            Center::updateOrCreate(
                ['code' => $row['code']],
                [
                    'name' => $row['name'],
                    'phone' => $row['phone'],
                    'address' => $row['address'],
                ]
            );
        }
    }
}
