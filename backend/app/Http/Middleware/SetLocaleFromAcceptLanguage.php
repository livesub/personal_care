<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\App;
use Symfony\Component\HttpFoundation\Response;

class SetLocaleFromAcceptLanguage
{
    private const ALLOWED = ['ko', 'en', 'vi'];

    public function handle(Request $request, Closure $next): Response
    {
        $locale = $request->header('Accept-Language');
        if ($locale !== null && $locale !== '') {
            $locale = strtolower(substr($locale, 0, 2));
            if (in_array($locale, self::ALLOWED, true)) {
                App::setLocale($locale);
            }
        }

        return $next($request);
    }
}
