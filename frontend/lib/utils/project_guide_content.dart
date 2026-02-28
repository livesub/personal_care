/// 프로젝트 가이드 구조화 데이터 — 카드/리스트/칩/경고 배너 렌더링용

class GuideSection {
  const GuideSection({
    required this.title,
    this.subtitle,
    this.techChips = const [],
    this.items = const [],
    this.alertItems = const [],
  });

  final String title;
  final String? subtitle;
  final List<GuideTechChip> techChips;
  final List<String> items;
  final List<String> alertItems;
}

class GuideTechChip {
  const GuideTechChip({required this.label, this.icon, this.description});

  final String label;
  final String? icon; // Icons 이름 또는 이모지
  final String? description;
}

/// 가이드 섹션 목록 (원문 구조 유지, UI용 구조화)
List<GuideSection> get projectGuideSections => [
      GuideSection(
        title: '시스템 기초 및 개발 환경 (Technology Stack)',
        subtitle:
            '프로젝트의 뼈대가 되는 기술과 버전 정보입니다. 초보자분들을 위해 각 기술의 역할도 상세히 풀었습니다.',
        techChips: const [
          GuideTechChip(label: 'Web', description: '크롬 등'),
          GuideTechChip(label: 'Android', description: '갤럭시'),
          GuideTechChip(label: 'iOS', description: '아이폰'),
          GuideTechChip(label: 'Flutter', description: 'Dart 최신'),
          GuideTechChip(label: 'Laravel 12', description: 'PHP 8.5'),
          GuideTechChip(label: 'MySQL 8.x', description: '데이터베이스'),
          GuideTechChip(label: 'Sanctum', description: '인증'),
          GuideTechChip(label: 'Argon2id / AES-256', description: '암호화'),
        ],
        items: const [
          '개발 플랫폼: 단일 코드베이스로 Web, Android, iOS를 모두 지원합니다. 어디서든 똑같은 화면을 볼 수 있습니다.',
          '프론트엔드(화면): Flutter. 구글이 만든 최신 기술로, shared_preferences로 로그인 정보를 안전하게 기억합니다.',
          '백엔드(엔진): PHP 8.5 / Laravel 12. 속도가 빠르고 보안이 강력하며, 복잡한 급여 계산을 담당합니다.',
          '데이터베이스: MySQL 8.x. 보호사와 관리자 정보를 각각 다른 Table에 나누어 보관합니다.',
        ],
        alertItems: const [
          'Sanctum: 로그인 후 생성되는 "디지털 입장권". 새로고침해도 로그인이 유지됩니다.',
          'Argon2id & AES-256-CBC: 비밀번호와 개인정보를 은행 수준으로 암호화하여, 관리자조차 비밀번호 원문을 볼 수 없게 보호합니다.',
        ],
      ),
      GuideSection(
        title: '사용자별 핵심 서비스 흐름 (Workflow)',
        subtitle: 'A. 보호사 (Helper): 계정 생성부터 급여 확인까지',
        items: const [
          '아이디 생성: 관리자가 보호사의 휴대폰 번호로 초기 계정을 만들어줍니다.',
          '실시간 업무: 정해진 시간 전후 20분에만 [시작] 버튼이 나타나 정직한 근무를 유도합니다.',
          '업무 종료: 오늘 이용자님의 상태를 적는 "업무 일지"를 써야 종료가 가능합니다.',
          '조기 종료 시 "왜 일찍 종료하시나요?" 팝업으로 사유 입력 필수입니다.',
          '급여 카운트업: 홈 화면에서 이번 달 예상 금액이 0원부터 목표 금액까지 애니메이션으로 표시됩니다.',
        ],
        alertItems: const [
          '보안 강화(10자 비밀번호): 최초 로그인 시 반드시 10자리 이상(영문+숫자+특수문자)의 새 비밀번호로 바꿔야 합니다. 변경 전에는 다른 어떤 기능도 쓸 수 없게 차단됩니다.',
          '로그인 가드: 보호사가 아닌 사람(관리자 등)이 보호사 페이지로 접속하려 하면 시스템이 즉시 감지하여 차단합니다.',
        ],
      ),
      GuideSection(
        title: '관리자 (Admin): 임시 계정 폭파와 정식 운영',
        items: const [
          '등급별 권한: "슈퍼 관리자"와 정산만 못 보는 "일반 스태프"로 명확히 나뉩니다.',
        ],
        alertItems: const [
          '임시 계정 파괴(Hard Delete): 초기용 아이디(admin_센터코드)로 접속해 정식 관리자를 등록하는 순간, 그 임시 아이디는 서버에서 영구히 삭제되어 보안 허점을 없앱니다.',
        ],
      ),
      GuideSection(
        title: '관리자 메뉴별 상세 기능',
        items: const [
          '① 대시보드: 통계 카드(보호사/이용자 수, 오늘 일정), 라이브 모니터링(상태별 색상 뱃지).',
          '② 회원 관리: 보호사 다중 소속, 이용자 바우처·비상 연락처, 계정 잠금 해제.',
          '③ 매칭 관리: 전역 중복 체크(Conflict Check), 맞춤 시급 설정, 조기 종료 기록.',
          '④ 실시간 모니터링: 지각 알림(10분 경과 시 빨갛게 강조), 상태 필터링(전체/서비스 중/시작 전/조기 종료/완료).',
          '⑤ 행정 및 정산: 분 단위 합산, 야간·공휴일 자동 수당 계산, 정산 리스트 엑셀 출력.',
          '⑥ 운영 설정: 스태프 등록(스태프는 관리자 추가·정산 메뉴 불가), 실시간 공지 팝업 연동.',
        ],
        alertItems: const [
          '보안: 스태프는 "관리자"를 추가할 수 없고 "정산" 메뉴도 볼 수 없습니다.',
        ],
      ),
      GuideSection(
        title: '프로젝트의 독보적 완성도 (Summary)',
        items: const [
          '철통 보안 라우팅: 주소창에 강제로 주소를 치고 들어와도 권한이 없으면 무조건 쫓아내는 보안 가드가 작동합니다.',
          '새로고침 무적: 인터넷 창을 새로고침해도 로그인이 풀리지 않아 업무의 연속성을 보장합니다.',
        ],
      ),
    ];
