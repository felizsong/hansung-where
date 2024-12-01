import 'package:mysql_client/mysql_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'Post.dart'; // Post 모델 임포트
import 'Comment.dart';
import 'NoticePost.dart'; // Post 모델 임포트

class DbConn {
  static MySQLConnection? _connection;

  // 데이터베이스 연결
  static Future<MySQLConnection> getConnection() async {
    if (_connection == null || !_connection!.connected) {
      print("Connecting to MySQL server...");

      await dotenv.load(); // 환경 변수 로드

      _connection = await MySQLConnection.createConnection(
        host: dotenv.env['db.host']!,
        port: 3306,
        userName: dotenv.env['db.user']!,
        password: dotenv.env['db.password']!,
        databaseName: dotenv.env['db.name']!,
      );
      await _connection!.connect();
    }
    return _connection!;
  }

  // 연결 종료
  static Future<void> closeConnection() async {
    if (_connection != null && _connection!.connected) {
      await _connection!.close();
      _connection = null;
      print("MySQL 연결 종료");
    }
  }

  // 사용자 정보 저장
  static Future<void> saveUser(String studentId) async {
    final conn = await getConnection();
    const profileId = 1; // 기본 프로필 ID

    try {
      // 학생 ID 확인
      final results = await conn.execute(
        'SELECT COUNT(*) AS count FROM users WHERE student_id = :studentId',
        {'studentId': studentId},
      );

      final count = results.rows.first.assoc()['count'];
      if (count == '0') {
        String nickname;
        bool isUnique;

        // 닉네임 중복 확인
        do {
          final randomNum =
              (1 + (999 - 1) * (DateTime.now().millisecondsSinceEpoch % 1000))
                  .toString();
          nickname = '부기$randomNum';
          final nicknameResults = await conn.execute(
            'SELECT COUNT(*) AS count FROM users WHERE nickname = :nickname',
            {'nickname': nickname},
          );

          isUnique = nicknameResults.rows.first.assoc()['count'] == '0';
        } while (!isUnique);

        // 사용자 정보 삽입
        await conn.execute(
          'INSERT INTO users (student_id, nickname, profile) VALUES (:studentId, :nickname, :profileId)',
          {
            'studentId': studentId,
            'nickname': nickname,
            'profileId': profileId
          },
        );
      }

      print("사용자 정보 저장 완료");
    } catch (e) {
      print("Error in saveUser: $e");
    }
  }

  // 닉네임 가져오기
  static Future<String?> getNickname(String studentId) async {
    final connection = await getConnection();
    try {
      final result = await connection.execute(
        'SELECT nickname FROM users WHERE student_id = :studentId',
        {'studentId': studentId},
      );
      if (result.rows.isNotEmpty) {
        return result.rows.first.assoc()['nickname'];
      }
    } catch (e) {
      print("Error fetching nickname: $e");
    }
    return null;
  }

  // 닉네임 업데이트
  static Future<bool> updateNickname(
      String studentId, String newNickname) async {
    final connection = await getConnection();
    try {
      final result = await connection.execute(
        'UPDATE users SET nickname = :newNickname WHERE student_id = :studentId',
        {'newNickname': newNickname, 'studentId': studentId},
      );
      return result.affectedRows > BigInt.zero;
    } catch (e) {
      print("Error updating nickname: $e");
    }
    return false;
  }

  // 닉네임 중복 확인
  static Future<bool> checkNickname(String nickname) async {
    final connection = await getConnection();
    try {
      final result = await connection.execute(
        'SELECT COUNT(*) AS count FROM users WHERE nickname = :nickname',
        {'nickname': nickname},
      );
      final count = result.rows.first.assoc()['count'];
      return count == '0'; // 중복된 닉네임이 없으면 true 반환
    } catch (e) {
      print("Error checking nickname uniqueness: $e");
      return false;
    }
  }

  // 프로필 ID 가져오기
  static Future<int> getProfileId(String studentId) async {
    final connection = await getConnection();
    try {
      final result = await connection.execute(
        'SELECT profile FROM users WHERE student_id = :studentId',
        {'studentId': studentId},
      );
      if (result.rows.isNotEmpty) {
        return int.parse(result.rows.first.assoc()['profile'] ?? '0');
      }
    } catch (e) {
      print("Error fetching profile ID: $e");
    }
    return 1; // 기본값
  }

  // 프로필 업데이트
  static Future<bool> updateProfile(String studentId, int newProfileId) async {
    final connection = await getConnection();
    try {
      final result = await connection.execute(
        'UPDATE users SET profile = :newProfileId WHERE student_id = :studentId',
        {'newProfileId': newProfileId, 'studentId': studentId},
      );
      return result.affectedRows > BigInt.zero;
    } catch (e) {
      print("Error updating profile: $e");
    }
    return false;
  }

  // 게시물 저장
  static Future<bool> savePost({
    required String title,
    required String body,
    required int userId,
    String? imageUrl1,
    String? imageUrl2,
    String? imageUrl3,
    String? imageUrl4,
    required String type,
    required String? place,
    required String? thing,
  }) async {
    final connection = await getConnection();
    try {
      // SQL 쿼리 실행
      final result = await connection.execute(
        '''
        INSERT INTO posts (title, body, user_id, image_url1, image_url2, image_url3, image_url4, type, place_keyword, thing_keyword) 
        VALUES (:title, :body, :userId, :imageUrl1, :imageUrl2, :imageUrl3, :imageUrl4, :type, :place, :thing)
        ''',
        {
          'title': title,
          'body': body,
          'userId': userId,
          'imageUrl1': imageUrl1,
          'imageUrl2': imageUrl2,
          'imageUrl3': imageUrl3,
          'imageUrl4': imageUrl4,
          'type': type,
          'place': place,
          'thing': thing,
        },
      );

      // 성공 여부 반환
      return result.affectedRows > BigInt.zero;
    } catch (e) {
      print("Error saving post: $e");
      return false;
    }
  }

  //장소 별 found 게시물 수를 가져옴(지도에서 사용)
  static Future<int> getFoundPostCount(String placeKeyword) async {
    final connection = await getConnection();
    try {
      final result = await connection.execute(
        '''
        SELECT COUNT(*) AS count 
        FROM posts 
        WHERE type = 'found' 
        AND place_keyword = :placeKeyword
        AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
      ''',
        {'placeKeyword': placeKeyword},
      );
      return int.parse(result.rows.first.assoc()['count'] ?? '0');
    } catch (e) {
      print("Error fetching found post count: $e");
      return 0;
    }
  }

  //게시물 가져오기
  static Future<List<Post>> fetchPosts({
    required String type,
    String? placeKeyword,
    String? thingKeyword,
  }) async {
    final connection = await getConnection(); // 연결 유지
    List<Post> posts = [];

    try {
      String sql = '''
    SELECT 
      post_id,
      title, 
      body, 
      created_at, 
      user_id,
      image_url1, 
      place_keyword, 
      thing_keyword 
    FROM 
      posts 
    WHERE 
      type = :type
    ''';

      if (placeKeyword != null) {
        sql += " AND place_keyword = :placeKeyword";
      }
      if (thingKeyword != null) {
        sql += " AND thing_keyword = :thingKeyword";
      }

      sql += " ORDER BY created_at DESC";

      final results = await connection.execute(sql, {
        'type': type,
        if (placeKeyword != null) 'placeKeyword': placeKeyword,
        if (thingKeyword != null) 'thingKeyword': thingKeyword,
      });

      for (final row in results.rows) {
        final rawCreatedAt = row.assoc()['created_at'];
        final relativeTime = _calculateRelativeTime(rawCreatedAt);

        posts.add(Post(
          postId: int.tryParse(row.assoc()['post_id']?.toString() ?? '') ?? 0,
          title: row.assoc()['title'] ?? '',
          body: row.assoc()['body'] ?? '',
          createdAt: relativeTime,
          // 상대적 시간으로 변환된 값 사용
          userId: int.tryParse(row.assoc()['user_id']?.toString() ?? '') ?? 0,
          imageUrl1: row.assoc()['image_url1'],
          place: row.assoc()['place_keyword'],
          thing: row.assoc()['thing_keyword'],
        ));
      }
    } catch (e) {
      print('Error fetching posts: $e');
    }

    return posts; // 연결을 닫지 않고 재사용
  }

  static String _calculateRelativeTime(String? createdAt) {
    if (createdAt == null) return '';
    final createdAtDate = DateTime.parse(createdAt);
    final now = DateTime.now();
    final difference = now.difference(createdAtDate);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else {
      return '${difference.inDays}일 전';
    }
  }

  // postId로 게시물 내용 가져오기
  static Future<Map<String, dynamic>?> getPostById(int postId) async {
    final connection = await getConnection();
    try {
      // execute로 SELECT 쿼리 실행
      final result = await connection.execute(
        '''
      SELECT *
      FROM posts 
      WHERE post_id = :postId
      ''',
        {'postId': postId},
      );

      // 결과가 없다면 null 반환
      if (result.rows.isEmpty) return null;

      // 첫 번째 행 가져오기
      final row = result.rows.first.assoc();

      // 생성 날짜 포맷팅 MM/DD HH:MM 형식으로
      if (row['created_at'] != null) {
        row['created_at'] = _formatDate(row['created_at']);
      }

      // 결과가 있다면 한 줄로 반환
      return row.map((key, value) => MapEntry(
            key,
            value ??
                (['title', 'body', 'created_at'].contains(key) ? '' : null),
          ));
    } catch (e) {
      print("Error retrieving post: $e");
      return null;
    }
  }

  //공지사항을 저장
  static Future<bool> saveNoticePost({
    required String title,
    required String body,
    required int managerId,
  }) async {
    final connection = await getConnection();
    try {
      // SQL 쿼리 실행
      final result = await connection.execute(
        '''
        INSERT INTO notices (title, body, manager_id) 
        VALUES (:title, :body, :managerId)
        ''',
        {
          'title': title,
          'body': body,
          'managerId': managerId,
        },
      );

      // 성공 여부 반환
      return result.affectedRows > BigInt.zero;
    } catch (e) {
      print("Error saving notice post: $e");
      return false;
    }
  }

  // 날짜를 MM/dd HH:mm 형식으로 포맷
  static String _formatDate(dynamic createdAt) {
    if (createdAt == null) return '';

    try {
      DateTime parsedDate;

      if (createdAt is int) {
        // Unix timestamp를 DateTime으로 변환
        parsedDate = DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);
      } else if (createdAt is String) {
        // ISO 8601 문자열을 DateTime으로 변환
        parsedDate = DateTime.parse(createdAt);
      } else {
        return ''; // 처리할 수 없는 형식
      }

      // MM/dd HH:mm 형식으로 변환
      return '${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.day.toString().padLeft(2, '0')} ${parsedDate.hour.toString().padLeft(2, '0')}:${parsedDate.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      print("Error formatting date: $e");
      return '';
    }
  }

  // 댓글 저장하기
  static Future<bool> saveComment({
    required int postId,
    required int userId,
    required String body,
    required String type,
    int? parentCommentId,
  }) async {
    final connection = await getConnection();
    bool success = false;

    try {
      var result = await connection.execute(
        '''
        INSERT INTO comments (post_id, user_id, body, type, parent_comment_id) 
        VALUES (:postId, :userId, :body, :type, :parentCommentId)
        ''',
        {
          'postId': postId,
          'userId': userId,
          'body': body,
          'type': type,
          'parentCommentId': parentCommentId,
        },
      );

      return result.affectedRows > BigInt.zero;
    } catch (e) {
      print('DB 연결 실패: $e');
    } finally {
      await connection.close();
    }

    return false;
  }

  // 댓글 가져오기
  static Future<List<Comment>> fetchComments({
    required int postId,
  }) async {
    final connection = await getConnection();
    List<Comment> comments = [];
    Map<int, List<Comment>> groupedComments = {}; // 댓글 그룹화 위한 맵

    try {
      final result = await connection.execute(
        '''
      SELECT *
      FROM comments 
      WHERE post_id = :postId
      ''',
        {'postId': postId},
      );

      for (final row in result.rows) {
        final rawCreatedAt = row.assoc()['created_at'];
        final formattedCreatedAt =
            rawCreatedAt != null ? _formatDate(rawCreatedAt) : '';

        final comment = Comment(
          commentId:
              int.tryParse(row.assoc()['comment_id']?.toString() ?? '') ?? 0,
          postId: int.tryParse(row.assoc()['post_id']?.toString() ?? '') ?? 0,
          userId: int.tryParse(row.assoc()['user_id']?.toString() ?? '') ?? 0,
          body: row.assoc()['body'] ?? '',
          createdAt: formattedCreatedAt,
          type: row.assoc()['type'] ?? '',
          parentCommentId: row.assoc()['parent_comment_id'] != null
              ? int.tryParse(row.assoc()['parent_comment_id']?.toString() ?? '')
              : null,
        );

        // userId로 닉네임을 가져와서 댓글에 추가
        final nickname = await getNickname(comment.userId.toString());
        comment.nickname = nickname;

        comments.add(comment);

        // parent_comment_id에 따른 그룹화
        if (comment.parentCommentId != null) {
          if (!groupedComments.containsKey(comment.parentCommentId)) {
            groupedComments[comment.parentCommentId!] = [];
          }
          groupedComments[comment.parentCommentId!]!.add(comment);
        }
      }
    } catch (e) {
      print('Error fetching comments: $e');
    }

    // 댓글을 그룹화된 형태로 반환
    return comments;
  }

  // 공지사항 가져오기
  static Future<List<NoticePost>> fetchNoticePosts() async {
    final connection = await getConnection(); // MySQL 연결
    List<NoticePost> noticePosts = [];

    try {
      // notices 테이블에서 데이터를 가져오는 SQL 쿼리 실행
      final results = await connection.execute('''
      SELECT notice_id, title, body, created_at, manager_id
      FROM notices
      ORDER BY created_at DESC
      ''');

      for (final row in results.rows) {
        noticePosts.add(NoticePost(
          noticeId: int.tryParse(row.assoc()['notice_id'] ?? '0') ?? 0,
          title: row.assoc()['title'] ?? '',
          body: row.assoc()['body'] ?? '',
          createdAt: _calculateRelativeTime(row.assoc()['created_at']),
          // 상대 시간으로 변환
          managerId: int.tryParse(row.assoc()['manager_id'] ?? '0'),
        ));
      }
    } catch (e) {
      print("Error fetching notice posts: $e");
    }

    return noticePosts;
  }

  static Future<Map<String, dynamic>?> getNoticePostById(int noticeId) async {
    final connection = await getConnection();
    try {
      print("Fetching notice with ID: $noticeId"); // 디버깅 로그 추가

      final result = await connection.execute(
        '''
      SELECT 
        n.notice_id,
        n.title,
        n.body,
        n.created_at,
        u.student_id AS manager_id
      FROM 
        notices n
      LEFT JOIN 
        users u ON n.manager_id = u.student_id
      WHERE 
        n.notice_id = :noticeId
      ''',
        {'noticeId': noticeId},
      );

      if (result.rows.isEmpty) {
        print('No data found for noticeId: $noticeId'); // 디버깅 로그
        return null;
      }

      final row = result.rows.first.assoc();

      print('Fetched row: $row'); // 디버깅 로그

      if (row['created_at'] != null) {
        row['created_at'] = _formatDate(row['created_at']); // 날짜 포맷팅
      }

      return row.map((key, value) => MapEntry(
            key,
            value ?? '',
          ));
    } catch (e) {
      print("Error retrieving notice by ID: $e"); // 디버깅 로그
      return null;
    }
  }

  // 최신 공지사항 가져오기
  static Future<NoticePost?> fetchLatestNoticePosts() async {
    final connection = await getConnection();
    try {
      final result = await connection.execute(
          '''
      SELECT notice_id, title, body, created_at, manager_id 
      FROM notices 
      ORDER BY created_at DESC 
      LIMIT 1
      '''
      );

      if (result.rows.isNotEmpty) {
        final row = result.rows.first.assoc();
        return NoticePost(
          noticeId: int.tryParse(row['notice_id'] ?? '0') ?? 0,
          title: row['title'] ?? '',
          body: row['body'] ?? '',
          createdAt: _calculateRelativeTime(row['created_at']),
          managerId: int.tryParse(row['manager_id'] ?? '0'),
        );
      }
    } catch (e) {
      print('Error fetching latest notice: $e');
    }
    return null;
  }
}
