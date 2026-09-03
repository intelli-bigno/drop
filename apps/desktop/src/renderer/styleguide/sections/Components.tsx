// Components — 실물 컴포넌트 카탈로그 (BRU-172).
//
// 여기 있는 것은 전부 `components/`의 진짜 컴포넌트다. 마크업을 베껴 오지 않는다 —
// 베끼면 컴포넌트가 바뀌어도 쇼케이스는 옛 모습을 계속 보여주고, 그 순간 이 화면은
// 관측 도구가 아니라 거짓말이 된다.

import { useState } from 'react'
import { PageHead, Section, Specimen } from '../parts'
import { STYLEGUIDE_NOTES, STYLEGUIDE_PROJECTS, STYLEGUIDE_TAGS } from '../fixtures'

import { Icon, type IconName } from '../../components/Icon'
import { ConfirmDialog } from '../../components/ConfirmDialog'
import { PinDialog, type PinDialogMode } from '../../components/PinDialog'
import { TagList } from '../../components/TagList'
import { SelectionActionBar } from '../../components/SelectionActionBar'
import { CategoryFilter } from '../../components/CategoryFilter'
import { ScopeFilter } from '../../components/ScopeFilter'
import { ExportedFilter } from '../../components/ExportedFilter'
import { ProjectFilter } from '../../components/ProjectFilter'
import { ViewModeSelector } from '../../components/ViewModeSelector'
import { ShortcutCheatSheet } from '../../components/ShortcutCheatSheet'
import { SearchDialog } from '../../components/SearchDialog'
import { TagManagementDialog } from '../../components/TagManagementDialog'
import { NoteHistoryDialog } from '../../components/NoteHistoryDialog'
import { ShortcutSettingsDialog } from '../../components/ShortcutSettingsDialog'
import { TagPopover } from '../../components/TagPopover'
import { ProjectPopover } from '../../components/ProjectPopover'
import { TemplatePopover } from '../../components/TemplatePopover'
import { BulkTagPopover } from '../../components/BulkTagPopover'
import { AttachmentList } from '../../components/AttachmentList'
import { LinkPreviews } from '../../components/LinkPreviews'
import { LockedNoteOverlay } from '../../components/LockedNoteOverlay'
import { NoteViewer } from '../../components/NoteViewer'
import { CommentPanel } from '../../components/CommentPanel'
import { NotePreviewPanel } from '../../components/NotePreviewPanel'
import { UserMenu } from '../../components/UserMenu'
import { useToastStore } from '../../stores/toast'
import { copyResultMessage } from '../../lib/copy-feedback'

const ICON_NAMES: IconName[] = [
  'pencil',
  'folder',
  'inbox',
  'archive',
  'trash',
  'link',
  'image',
  'paperclip',
  'search',
  'pin',
  'lock',
  'lock-open',
  'corner-up-left',
  'x',
  'history',
  'check',
  'plus',
  'file-text',
  'camera',
  'play',
  'message-square',
  'chevrons-down',
  'chevrons-up',
  'square',
  'check-square',
  'list-todo',
  'help-circle',
  'tag',
  'keyboard',
  'copy',
  'log-out',
  'youtube',
  'instagram',
]

const PIN_MODES: PinDialogMode[] = ['setup', 'unlock-temp', 'unlock-permanent', 'unlock-all']

/** 오버레이 컴포넌트는 화면 전체를 덮으므로 버튼으로 열어 본다. */
type OverlayId =
  | 'confirm'
  | 'confirm-danger'
  | 'cheatsheet'
  | 'search'
  | 'tags'
  | 'history'
  | 'shortcuts'
  | 'comments'
  | 'preview'
  | PinDialogMode

export function Components() {
  const [overlay, setOverlay] = useState<OverlayId | null>(null)
  const showToast = useToastStore((s) => s.showToast)

  const noteWithTags = STYLEGUIDE_NOTES.find((n) => n.tags.length > 0) ?? STYLEGUIDE_NOTES[0]
  const noteWithFiles = STYLEGUIDE_NOTES.find((n) => n.attachments.length > 0) ?? STYLEGUIDE_NOTES[0]
  const noteWithLink = STYLEGUIDE_NOTES.find((n) => n.hasLink) ?? STYLEGUIDE_NOTES[0]
  const noteWithComments = STYLEGUIDE_NOTES[1]

  const close = () => setOverlay(null)

  return (
    <>
      <PageHead title="Components">
        전부 실물 컴포넌트다 — 픽스처를 스토어에 부어 두고 그대로 렌더한다. 서버에 닿는
        액션은 주입 단계에서 무해한 껍데기로 바뀌어 있으니 여기서 무엇을 눌러도 실제 노트는
        움직이지 않는다.
      </PageHead>

      <Section title="아이콘" note="lucide 계열 SVG, stroke=currentColor. 이모지는 쓰지 않는다.">
        <Specimen name="Icon" file="components/Icon.tsx">
          <div className="sg-grid sg-grid--tight">
            {ICON_NAMES.map((name) => (
              <div className="sg-stack" key={name} style={{ alignItems: 'center', gap: 6 }}>
                <Icon name={name} />
                <span className="sg-mono" style={{ color: 'var(--text-tertiary)' }}>
                  {name}
                </span>
              </div>
            ))}
          </div>
        </Specimen>
      </Section>

      <Section
        title="피드백"
        note="알림은 오른쪽 위에 뜬다 (BRU-213) — 읽던 글 위가 아니라 결과만 확인하고 지나가는 자리다. 소프트 삭제는 낙관적 적용 + 실행취소 토스트, 영구 삭제는 확인 다이얼로그를 거친다."
      >
        <Specimen name="Toaster" file="components/Toaster.tsx">
          <div className="sg-row">
            <button className="sg-btn" onClick={() => showToast({ message: '노트를 보관했습니다' })}>
              기본 토스트
            </button>
            <button
              className="sg-btn"
              onClick={() => showToast({ message: '저장에 실패했습니다', variant: 'error' })}
            >
              오류 토스트
            </button>
            <button
              className="sg-btn"
              onClick={() =>
                showToast({
                  message: '노트를 삭제했습니다',
                  actionLabel: '실행취소',
                  onAction: () => showToast({ message: '되돌렸습니다' }),
                })
              }
            >
              실행취소가 붙은 토스트
            </button>
            {/* 문구를 여기 다시 적지 않는다 — 앱이 쓰는 그 함수를 그대로 부른다. */}
            <button
              className="sg-btn"
              onClick={() => showToast(copyResultMessage('copyFocused', true))}
            >
              복사 확인 (⌘C)
            </button>
          </div>
        </Specimen>

        <Specimen name="ConfirmDialog" file="components/ConfirmDialog.tsx" desc="기본 포커스는 취소">
          <div className="sg-row">
            <button className="sg-btn" onClick={() => setOverlay('confirm')}>
              일반
            </button>
            <button className="sg-btn" onClick={() => setOverlay('confirm-danger')}>
              파괴적 (danger)
            </button>
          </div>
        </Specimen>
      </Section>

      <Section title="필터" note="피드 헤더에 나란히 붙는 것들. 전부 스토어를 직접 읽고 쓴다.">
        <Specimen name="ViewModeSelector" file="components/ViewModeSelector.tsx">
          <ViewModeSelector />
        </Specimen>
        <Specimen name="CategoryFilter" file="components/CategoryFilter.tsx">
          <CategoryFilter />
        </Specimen>
        <Specimen name="ProjectFilter" file="components/ProjectFilter.tsx">
          <ProjectFilter />
        </Specimen>
        <Specimen name="ScopeFilter · ExportedFilter" file="components/ScopeFilter.tsx">
          <div className="sg-row">
            <ScopeFilter />
            <ExportedFilter />
          </div>
        </Specimen>
      </Section>

      <Section title="태그" note="노트 폭이 좁아지면 넘치는 태그는 +N으로 접힌다.">
        <Specimen name="TagList" file="components/TagList.tsx">
          <TagList noteId={noteWithTags.id} tags={noteWithTags.tags} />
        </Specimen>
        <Specimen name="TagList — 넘침" desc="컨테이너를 좁히면 +N이 나타난다">
          <div style={{ width: 180 }}>
            <TagList noteId={noteWithTags.id} tags={STYLEGUIDE_TAGS} />
          </div>
        </Specimen>
      </Section>

      <Section
        title="팝오버"
        note="카드 바로 아래에 붙는 목록. 태그는 고른 뒤에도 열려 있고, 프로젝트는 하나만 고르므로 닫힌다."
      >
        <Specimen name="TagPopover" file="components/TagPopover.tsx">
          <div className="sg-anchor">
            <p className="sg-anchor-hint">노트 카드 아래에 붙는 자리를 흉내 낸 것</p>
            <TagPopover noteId={noteWithTags.id} tags={noteWithTags.tags} onClose={() => {}} />
          </div>
        </Specimen>

        <Specimen name="ProjectPopover" file="components/ProjectPopover.tsx">
          <div className="sg-anchor">
            <ProjectPopover
              noteId={noteWithTags.id}
              projectId={STYLEGUIDE_PROJECTS[0].id}
              onClose={() => {}}
            />
          </div>
        </Specimen>

        <Specimen name="TemplatePopover" file="components/TemplatePopover.tsx" desc="빈 노트에서 /">
          <div className="sg-anchor">
            <TemplatePopover onInsert={() => {}} onClose={() => {}} />
          </div>
        </Specimen>

        <Specimen name="BulkTagPopover" file="components/BulkTagPopover.tsx" desc="선택 집합에 일괄 부착">
          <div className="sg-anchor">
            <BulkTagPopover notes={STYLEGUIDE_NOTES.slice(0, 3)} onClose={() => {}} />
          </div>
        </Specimen>
      </Section>

      <Section title="선택 모드">
        <Specimen name="SelectionActionBar" file="components/SelectionActionBar.tsx" desc="active">
          <SelectionActionBar count={3} viewMode="active" onAction={() => {}} onClear={() => {}} />
        </Specimen>
        <Specimen name="SelectionActionBar" desc="trash — 액션 세트가 다르다">
          <SelectionActionBar count={1} viewMode="trash" onAction={() => {}} onClear={() => {}} />
        </Specimen>
      </Section>

      <Section title="노트 본문">
        <Specimen name="NoteViewer" file="components/NoteViewer.tsx" desc="읽기 전용 렌더">
          <NoteViewer content={'## 오늘 정한 것\n\n- 밀도는 4px 유지\n- `tokens.json`이 정본\n\n> 실측하지 못한 것은 못 했다고 쓴다'} />
        </Specimen>
        <Specimen name="AttachmentList" file="components/AttachmentList.tsx">
          <AttachmentList attachments={noteWithFiles.attachments} />
        </Specimen>
        <Specimen name="LinkPreviews" file="components/LinkPreviews.tsx" desc="본문 속 URL을 카드로">
          <LinkPreviews content={noteWithLink.content} attachments={[]} />
        </Specimen>
        <Specimen name="LockedNoteOverlay" file="components/LockedNoteOverlay.tsx">
          <LockedNoteOverlay onTemporaryUnlock={() => {}} onPermanentUnlock={() => {}} />
        </Specimen>
      </Section>

      <Section title="패널·다이얼로그" note="전부 backdrop + 포커스 트랩 + Escape 취소의 같은 패턴이다.">
        <Specimen name="오버레이" desc="전부 화면을 덮는 fixed 배치라 눌러서 연다">
          <div className="sg-row">
            <button className="sg-btn" onClick={() => setOverlay('cheatsheet')}>
              ShortcutCheatSheet
            </button>
            <button className="sg-btn" onClick={() => setOverlay('search')}>
              SearchDialog
            </button>
            <button className="sg-btn" onClick={() => setOverlay('tags')}>
              TagManagementDialog
            </button>
            <button className="sg-btn" onClick={() => setOverlay('history')}>
              NoteHistoryDialog
            </button>
            <button className="sg-btn" onClick={() => setOverlay('shortcuts')}>
              ShortcutSettingsDialog
            </button>
            <button className="sg-btn" onClick={() => setOverlay('comments')}>
              CommentPanel
            </button>
            <button className="sg-btn" onClick={() => setOverlay('preview')}>
              NotePreviewPanel (Space)
            </button>
          </div>
        </Specimen>

        <Specimen name="PinDialog" file="components/PinDialog.tsx" desc="네 가지 모드. 쇼케이스 PIN은 0000">
          <div className="sg-row">
            {PIN_MODES.map((mode) => (
              <button className="sg-btn" key={mode} onClick={() => setOverlay(mode)}>
                {mode}
              </button>
            ))}
          </div>
        </Specimen>
      </Section>

      <Section title="사용자 메뉴">
        <Specimen name="UserMenu" file="components/UserMenu.tsx" desc="하드코딩 색은 BRU-176으로 토큰 교체됨">
          <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
            <UserMenu onOpenCheatSheet={() => setOverlay('cheatsheet')} />
          </div>
        </Specimen>
      </Section>

      {/* ── 오버레이 실물 ── */}
      {overlay === 'confirm' && (
        <ConfirmDialog
          title="보관할까요?"
          message="보관한 노트는 보관함에서 다시 꺼낼 수 있습니다."
          confirmLabel="보관"
          onConfirm={close}
          onCancel={close}
        />
      )}
      {overlay === 'confirm-danger' && (
        <ConfirmDialog
          title="영구 삭제할까요?"
          message="이 노트와 댓글이 함께 사라지고 되돌릴 수 없습니다."
          confirmLabel="영구 삭제"
          danger
          onConfirm={close}
          onCancel={close}
        />
      )}
      {overlay === 'cheatsheet' && <ShortcutCheatSheet onClose={close} />}
      {overlay === 'search' && <SearchDialog onClose={close} onSelectNote={close} />}
      {overlay === 'tags' && <TagManagementDialog onClose={close} />}
      {overlay === 'history' && <NoteHistoryDialog noteId={noteWithComments.id} onClose={close} />}
      {overlay === 'shortcuts' && <ShortcutSettingsDialog onClose={close} />}
      {overlay === 'comments' && <CommentPanel noteId={noteWithComments.id} onClose={close} />}
      {/* 유일한 비모달 오버레이 (BRU-179) — backdrop이 없고 포커스를 가져가지 않는다.
          피드에서는 열린 채로 j/k가 뒤 목록을 계속 움직인다. */}
      {overlay === 'preview' && <NotePreviewPanel note={noteWithFiles} onClose={close} />}
      {overlay !== null && PIN_MODES.includes(overlay as PinDialogMode) && (
        <PinDialog mode={overlay as PinDialogMode} onSuccess={close} onCancel={close} />
      )}
    </>
  )
}
