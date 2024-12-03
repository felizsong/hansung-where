import 'package:flutter/material.dart';
import 'DbConn.dart';
import 'Report.dart';

class ReportCard extends StatelessWidget {
  final Report report;
  final bool showTypeIcon; // 타입에 따라 아이콘을 표시할지 여부

  const ReportCard({
    Key? key,
    required this.report,
    this.showTypeIcon = true,
  }) : super(key: key);

  Future<String?> _fetchReporterNickname(int userId) async {
    return await DbConn.getNickname(userId.toString());
  }

  @override
  Widget build(BuildContext context) {
    final GlobalKey _dotsKey = GlobalKey();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white, // 카드 배경색
        borderRadius: BorderRadius.circular(12.0), // 둥근 모서리
        border:
            Border.all(color: const Color(0xFFECECEC), width: 1.5), // 회색 테두리
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 신고 유형 표시
              if (showTypeIcon)
                Row(
                  children: [
                    Icon(
                      _getIconForType(report.type),
                      color: Colors.redAccent,
                      size: 16.0,
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      _getTypeLabel(report.type),
                      style: const TextStyle(
                        fontFamily: 'Neo',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              if (showTypeIcon) const SizedBox(height: 6.0),

              // 신고 이유
              Text(
                '신고 이유: ${report.reason}',
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'Neo',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8.0),

              // 신고 시간 및 신고자 정보
              FutureBuilder<String?>(
                future: _fetchReporterNickname(report.userId),
                builder: (context, snapshot) {
                  String reporterName = snapshot.data ?? '알 수 없음'; // 기본값
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    reporterName = '';
                  }
                  return RichText(
                    text: TextSpan(
                      text: '${report.reportedAt} | ',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black,
                        fontFamily: 'Neo',
                      ),
                      children: [
                        TextSpan(
                          text: '신고자: $reporterName',
                          style: const TextStyle(
                            color: Color(0xFF042D6F),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              key: _dotsKey, // 고유 GlobalKey 연결
              onTap: () {
                _showReportPopupMenu(context, _dotsKey); // 팝업 메뉴 호출
              },
              child: Image.asset(
                'assets/icons/ic_dots.png',
                width: 24.0,
                height: 24.0,
              ),
            ),
          ),

        ],
      ),
    );
  }
  void _showReportPopupMenu(BuildContext context, GlobalKey key) async {
    final RenderBox renderBox = key.currentContext?.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);

    final RenderBox overlay = Overlay.of(context)!.context.findRenderObject() as RenderBox;

    await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx, // 점 버튼의 x 위치
        position.dy + renderBox.size.height, // 점 버튼 아래
        overlay.size.width - position.dx - renderBox.size.width,
        0,
      ),
      color: Colors.white, // 팝업 배경 흰색
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10), // 둥근 모서리
        side: const BorderSide(
          color: Color(0xFFC0C0C0), // 회색 테두리
          width: 1,
        ),
      ),
      items: [
        _buildPopupMenuItem(
          text: "3일 정지",
          onTap: () {
            Navigator.pop(context); // 팝업 닫기
            _showActionDialog(context, "3일 정지", "이 유저를 3일 정지하시겠습니까?");
          },
        ),
        _buildDivider(),
        _buildPopupMenuItem(
          text: "삭제하기",
          onTap: () {
            Navigator.pop(context); // 팝업 닫기
            _showActionDialog(context, "삭제하기", "이 신고를 삭제하시겠습니까?");
          },
        ),
      ],
    );
  }


  void _showActionDialog(BuildContext context, String action, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            action,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // 다이얼로그 닫기
              },
              child: const Text(
                "취소",
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // 다이얼로그 닫기
                if (action == "3일 정지") {
                  print("유저 3일 정지 처리");
                  // 3일 정지 로직 추가
                } else if (action == "삭제하기") {
                  print("신고 삭제 처리");
                  // 신고 삭제 로직 추가
                }
              },
              child: const Text(
                "확인",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }

  PopupMenuItem _buildPopupMenuItem({
    required String text,
    required VoidCallback onTap,
  }) {
    return PopupMenuItem(
      padding: EdgeInsets.zero, // 기본 패딩 제거
      height: 40, // 고정된 높이
      child: InkWell(
        onTap: onTap,
        child: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: Colors.black),
          ),
        ),
      ),
    );
  }

  PopupMenuItem _buildDivider() {
    return PopupMenuItem(
      padding: EdgeInsets.zero,
      height: 1,
      child: Divider(
        height: 1,
        thickness: 1,
        color: const Color(0xFFC0C0C0),
      ),
    );
  }


  // 신고 유형에 따른 아이콘 선택
  IconData _getIconForType(String type) {
    switch (type) {
      case 'post':
        return Icons.article;
      case 'comment':
        return Icons.comment;
      case 'reply':
        return Icons.reply;
      default:
        return Icons.report;
    }
  }

  // 신고 유형에 따른 라벨 반환
  String _getTypeLabel(String type) {
    switch (type) {
      case 'post':
        return '게시글 신고';
      case 'comment':
        return '댓글 신고';
      case 'reply':
        return '답글 신고';
      default:
        return '알 수 없음';
    }
  }
}
