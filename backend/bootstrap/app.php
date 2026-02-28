<?php

use Illuminate\Auth\AuthenticationException;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\App;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->api(prepend: [
            \App\Http\Middleware\SetLocaleFromAcceptLanguage::class,
        ]);
        $middleware->alias([
            'restrict.staff.settings' => \App\Http\Middleware\RestrictStaffSettings::class,
            'set.current.center' => \App\Http\Middleware\SetCurrentCenterId::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        // API 경로 인증 실패 시 표준 에러 형식으로 401 반환 (.cursorrules §5)
        $exceptions->render(function (AuthenticationException $e, Request $request) {
            if ($request->is('api/*')) {
                $locale = $request->header('Accept-Language');
                if ($locale) {
                    $locale = strtolower(substr($locale, 0, 2));
                    if (in_array($locale, ['ko', 'en', 'vi'], true)) {
                        App::setLocale($locale);
                    }
                }
                return response()->json([
                    'app' => 'Personal Care',
                    'code' => 'ERR_AUTH_001',
                    'message' => __('auth_unauthenticated'),
                    'hint' => 'Authentication required. Token missing or invalid.',
                ], 401);
            }
        });
    })
    ->withSchedule(function (Schedule $schedule): void {
        $schedule->command('matchings:send-end-reminder')->everyMinute();
    })
    ->create();
