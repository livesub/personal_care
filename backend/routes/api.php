<?php

use App\Http\Controllers\Api\AdminAdminsIndexController;
use App\Http\Controllers\Api\AdminAdminStoreController;
use App\Http\Controllers\Api\AdminDashboardController;
use App\Http\Controllers\Api\AdminAuthController;
use App\Http\Controllers\Api\AdminCompleteSetupController;
use App\Http\Controllers\Api\AdminClientDestroyController;
use App\Http\Controllers\Api\AdminClientsIndexController;
use App\Http\Controllers\Api\AdminClientStoreController;
use App\Http\Controllers\Api\AdminMatchingCreateController;
use App\Http\Controllers\Api\AdminMatchingDestroyController;
use App\Http\Controllers\Api\AdminMatchingStoreController;
use App\Http\Controllers\Api\AdminMatchingUpdateController;
use App\Http\Controllers\Api\AdminMatchingsIndexController;
use App\Http\Controllers\Api\AdminMenusController;
use App\Http\Controllers\Api\NoticeCheckNewController;
use App\Http\Controllers\Api\NoticeDestroyController;
use App\Http\Controllers\Api\NoticeIndexController;
use App\Http\Controllers\Api\NoticeStoreController;
use App\Http\Controllers\Api\NoticeUpdateController;
use App\Http\Controllers\Api\AdminSettlementController;
use App\Http\Controllers\Api\AdminSettingsController;
use App\Http\Controllers\Api\AdminUserCheckController;
use App\Http\Controllers\Api\AdminUserStoreController;
use App\Http\Controllers\Api\AdminUsersIndexController;
use App\Http\Controllers\Api\AdminUserDestroyController;
use App\Http\Controllers\Api\AdminUserUnlockController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CentersController;
use App\Http\Controllers\Api\ChangePasswordController;
use App\Http\Controllers\Api\CompleteFirstLoginController;
use App\Http\Controllers\Api\ForgotPasswordAdminController;
use App\Http\Controllers\Api\ForgotPasswordHelperController;
use App\Http\Controllers\Api\HelperAuthController;
use App\Http\Controllers\Api\HelperHomeController;
use App\Http\Controllers\Api\LockAccountController;
use App\Http\Controllers\Api\ResetPasswordController;
use App\Http\Controllers\Api\UserEndWorkController;
use App\Http\Controllers\Api\UserLockController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes (인증 불필요)
|--------------------------------------------------------------------------
*/

Route::post('/helper/login', [HelperAuthController::class, 'login']);
Route::post('/helper/complete-first-login', CompleteFirstLoginController::class);
Route::get('/centers', [CentersController::class, 'index']);
Route::post('/helper/forgot-password', ForgotPasswordHelperController::class);
Route::post('/helper/reset-password', ResetPasswordController::class);
Route::post('/auth/lock-account', LockAccountController::class);

/*
|--------------------------------------------------------------------------
| 관리자 API (prefix: admin) — 로그인/비밀번호 찾기는 인증 없음, 그 외 auth:sanctum
|--------------------------------------------------------------------------
*/
Route::prefix('admin')->group(function (): void {
    Route::post('login', [AdminAuthController::class, 'login']);
    Route::post('forgot-password', ForgotPasswordAdminController::class);

    Route::middleware(['auth:sanctum', 'set.current.center', 'restrict.staff.settings'])->group(function (): void {
        Route::get('dashboard', AdminDashboardController::class);
        Route::get('menus', AdminMenusController::class);
        Route::get('settings', [AdminSettingsController::class, 'index']);
        Route::patch('settings', [AdminSettingsController::class, 'update']);
        Route::get('users/check', AdminUserCheckController::class);
        Route::get('users', AdminUsersIndexController::class);
        Route::delete('users/{id}', AdminUserDestroyController::class);
        Route::post('users/{id}/unlock', AdminUserUnlockController::class);
        Route::post('complete-setup', AdminCompleteSetupController::class);
        Route::get('clients', AdminClientsIndexController::class);
        Route::post('clients', AdminClientStoreController::class);
        Route::delete('clients/{id}', AdminClientDestroyController::class);
        Route::post('users', AdminUserStoreController::class);
        Route::get('admins', AdminAdminsIndexController::class);
        Route::post('admins', AdminAdminStoreController::class);
        Route::get('matchings/create', AdminMatchingCreateController::class);
        Route::get('matchings', AdminMatchingsIndexController::class);
        Route::get('settlement/export', [AdminSettlementController::class, 'export']);
        Route::get('settlement', [AdminSettlementController::class, 'index']);
        Route::get('notices', NoticeIndexController::class);
        Route::post('notices', NoticeStoreController::class);
        Route::patch('notices/{id}', NoticeUpdateController::class);
        Route::delete('notices/{id}', NoticeDestroyController::class);
        Route::post('matchings', AdminMatchingStoreController::class);
        Route::patch('matchings/{id}', AdminMatchingUpdateController::class);
        Route::delete('matchings/{id}', AdminMatchingDestroyController::class);
    });
});

/*
|--------------------------------------------------------------------------
| 보호사(users) API (auth:sanctum 인증 필요)
|--------------------------------------------------------------------------
*/
Route::middleware(['auth:sanctum', 'set.current.center'])->group(function (): void {
    Route::get('/user', [AuthController::class, 'me']);
    Route::get('/notices/check-new', NoticeCheckNewController::class);
    Route::get('/helper/home', [HelperHomeController::class, 'home']);
    Route::post('/helper/matchings/{id}/start', [HelperHomeController::class, 'start']);
    Route::post('/helper/matchings/{id}/complete', [HelperHomeController::class, 'complete']);
    Route::post('/user/lock', UserLockController::class);
    Route::post('/user/change-password', ChangePasswordController::class);
    Route::post('/user/end-work', UserEndWorkController::class);
    Route::post('/logout', [AuthController::class, 'logout']);
});
