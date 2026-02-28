import 'package:flutter/material.dart';

/// Personal Care 브랜드 컬러
/// 디자인 참고: Green 톤 (1_AI 로그인.pdf 기준)
class AppColors {
  // 메인 컬러 - Green 톤 (문서 요구사항)
  static const Color primary = Color(0xFF4CAF50); // 메인 그린
  static const Color primaryLight = Color(0xFF81C784); // 밝은 그린
  static const Color primaryDark = Color(0xFF388E3C); // 진한 그린
  static const Color mintGreen = Color(0xFF6FABA9); // 민트색 (확인 버튼)
  
  // 배경 컬러
  static const Color background = Color(0xFFF5F5F5); // 연한 회색
  static const Color cardBackground = Colors.white;
  
  // 액션 컬러
  static const Color success = Color(0xFF6FABA9); // 확인/성공
  static const Color error = Color(0xFFE57373); // 취소/에러
  static const Color warning = Color(0xFFFFA726);
  
  // 텍스트 컬러
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textHint = Color(0xFF999999);
  
  // 관리자 웹 컬러 (참고: docs/design/관리자구성 이미지.png)
  static const Color adminNav = Color(0xFF5B8FD4); // 상단 네비
  static const Color adminSidebar = Color(0xFFF8F9FA); // 사이드바
  static const Color adminActive = Color(0xFF5B8FD4); // 활성 메뉴
  /// 중복 근무(부정 수급) 의심 행 배경 — 연한 빨강 #FFE5E5
  static const Color duplicateRow = Color(0xFFFFE5E5);
}
