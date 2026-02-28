<?php

namespace Database\Seeders;

use App\Models\Matching;
use App\Models\User;
use App\Models\Center;
use Illuminate\Database\Seeder;
use Carbon\Carbon;

/**
 * 테스트용 배정. 현재 시각을 포함하는 구간으로 1건 생성.
 */
class MatchingSeeder extends Seeder
{
    public function run(): void
    {
        $user = User::where('login_id', '01012345678')->first();
        $center = Center::first();
        if (! $user || ! $center) {
            return;
        }
        $now = Carbon::now();
        $startAt = $now->copy()->subHours(2);
        $endAt = $now->copy()->addHours(4);
        Matching::updateOrCreate(
            [
                'user_id' => $user->user_id,
                'center_id' => $center->id,
            ],
            [
                'start_at' => $startAt,
                'end_at' => $endAt,
            ]
        );
    }
}
