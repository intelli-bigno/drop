/// DROP 도메인 로직 — apps/ios/Packages/DropCore 의 Dart 판.
///
/// Flutter SDK를 import하지 않는다. 여기 있는 모든 것은 `dart test`로
/// 에뮬레이터 없이 검증된다. 포팅 스펙은 DropCore의 Swift 테스트 스위트다.
library;

export 'src/attachment.dart';
export 'src/auth_store.dart';
export 'src/comments_repository.dart';
export 'src/comments_store.dart';
export 'src/composer_media.dart';
export 'src/drop_configuration.dart';
export 'src/drop_json.dart';
export 'src/in_memory_comments_repository.dart';
export 'src/in_memory_notes_repository.dart';
export 'src/markdown/markdown_document.dart';
export 'src/markdown/markdown_editor.dart';
export 'src/markdown/markdown_inline_parser.dart';
export 'src/markdown/markdown_parser.dart';
export 'src/markdown/markdown_summary_cache.dart';
export 'src/note.dart';
export 'src/note_assembler.dart';
export 'src/note_comment.dart';
export 'src/note_copying.dart';
export 'src/note_date_grouper.dart';
export 'src/note_hierarchy.dart';
export 'src/note_viewer_action.dart';
export 'src/notes_repository.dart';
export 'src/notes_store.dart';
export 'src/relative_time_formatter.dart';
export 'src/repository_error.dart';
export 'src/storage_path.dart';
export 'src/supabase/insert_payloads.dart';
export 'src/supabase/supabase_attachments_repository.dart';
export 'src/supabase/supabase_comments_repository.dart';
export 'src/supabase/supabase_notes_repository.dart';
export 'src/supabase/supabase_rest.dart';
export 'src/supabase/supabase_tags_repository.dart';
export 'src/tag.dart';
export 'src/transcription_service.dart';
