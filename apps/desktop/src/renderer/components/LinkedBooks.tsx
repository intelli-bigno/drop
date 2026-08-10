import { memo } from 'react'
import { Icon } from './Icon'
import { supabase } from '../lib/supabase'
import { useNotesStore } from '../stores/notes'
import type { Book } from '@drop/shared'

interface Props {
  noteId: string
  books: Book[]
}

export const LinkedBooks = memo(function LinkedBooks({ noteId, books }: Props) {
  const { unlinkNoteFromBook } = useNotesStore()

  if (books.length === 0) return null

  const handleUnlink = (bookId: string, e: React.MouseEvent) => {
    e.stopPropagation()
    void unlinkNoteFromBook(bookId, noteId)
  }

  return (
    <div className="linked-books">
      {books.map((book) => {
        const coverUrl = book.coverStoragePath
          ? supabase.storage.from('attachments').getPublicUrl(book.coverStoragePath).data.publicUrl
          : book.coverUrl

        return (
          <div key={book.id} className="linked-book">
            {coverUrl && (
              <img src={coverUrl} alt={book.title} className="linked-book-cover" />
            )}
            <div className="linked-book-info">
              <span className="linked-book-title">{book.title}</span>
              <span className="linked-book-author">{book.author}</span>
            </div>
            <button
              className="linked-book-unlink"
              onClick={(e) => handleUnlink(book.id, e)}
              title="연결 해제"
              aria-label="연결 해제"
            >
              <Icon name="x" size={12} />
            </button>
          </div>
        )
      })}
    </div>
  )
})
