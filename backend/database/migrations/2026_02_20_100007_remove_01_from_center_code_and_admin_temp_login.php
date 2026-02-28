<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * 기존 데이터 정리: 센터 코드에서 끝 '01' 제거, 임시 관리자 login_id를 admin_센터코드로 통일.
 * ※ 100008_make_admins_login_id_globally_unique 보다 먼저 실행되어야 함.
 * - centers.code 가 XXX01 형태면 XXX 로 변경.
 * - admins 에서 login_id='admin' 인 행을 해당 센터의 code 기준으로 login_id = 'admin_'.strtolower(code) 로 변경.
 */
return new class extends Migration
{
    public function up(): void
    {
        $centers = DB::table('centers')->get();
        foreach ($centers as $center) {
            $code = $center->code;
            $newCode = (str_ends_with($code, '01') && strlen($code) > 2)
                ? substr($code, 0, -2)
                : $code;

            if ($newCode !== $code) {
                DB::table('centers')->where('id', $center->id)->update(['code' => $newCode]);
            }

            $tempLoginId = 'admin_' . strtolower($newCode);
            DB::table('admins')
                ->where('center_id', $center->id)
                ->where('login_id', 'admin')
                ->update(['login_id' => $tempLoginId]);
        }
    }

    public function down(): void
    {
        // 되돌리지 않음. 필요 시 수동 복구.
    }
};
