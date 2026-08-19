export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      attachments: {
        Row: {
          author_name: string | null
          author_url: string | null
          caption: string | null
          created_at: string
          filename: string | null
          id: string
          metadata: Json | null
          mime_type: string | null
          note_id: string
          original_url: string | null
          size: number | null
          storage_path: string
          type: string
        }
        Insert: {
          author_name?: string | null
          author_url?: string | null
          caption?: string | null
          created_at?: string
          filename?: string | null
          id?: string
          metadata?: Json | null
          mime_type?: string | null
          note_id: string
          original_url?: string | null
          size?: number | null
          storage_path: string
          type: string
        }
        Update: {
          author_name?: string | null
          author_url?: string | null
          caption?: string | null
          created_at?: string
          filename?: string | null
          id?: string
          metadata?: Json | null
          mime_type?: string | null
          note_id?: string
          original_url?: string | null
          size?: number | null
          storage_path?: string
          type?: string
        }
        Relationships: [
          {
            foreignKeyName: "attachments_note_id_fkey"
            columns: ["note_id"]
            isOneToOne: false
            referencedRelation: "notes"
            referencedColumns: ["id"]
          },
        ]
      }
      book_notes: {
        Row: {
          book_id: string
          created_at: string
          note_id: string
        }
        Insert: {
          book_id: string
          created_at?: string
          note_id: string
        }
        Update: {
          book_id?: string
          created_at?: string
          note_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "book_notes_book_id_fkey"
            columns: ["book_id"]
            isOneToOne: false
            referencedRelation: "books"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "book_notes_note_id_fkey"
            columns: ["note_id"]
            isOneToOne: false
            referencedRelation: "notes"
            referencedColumns: ["id"]
          },
        ]
      }
      books: {
        Row: {
          author: string
          cover_storage_path: string | null
          cover_url: string | null
          created_at: string
          description: string | null
          finished_at: string | null
          id: string
          isbn13: string
          pub_date: string | null
          publisher: string | null
          rating: number | null
          reading_status: Database["public"]["Enums"]["reading_status"]
          started_at: string | null
          title: string
          updated_at: string
          user_id: string | null
        }
        Insert: {
          author: string
          cover_storage_path?: string | null
          cover_url?: string | null
          created_at?: string
          description?: string | null
          finished_at?: string | null
          id?: string
          isbn13: string
          pub_date?: string | null
          publisher?: string | null
          rating?: number | null
          reading_status?: Database["public"]["Enums"]["reading_status"]
          started_at?: string | null
          title: string
          updated_at?: string
          user_id?: string | null
        }
        Update: {
          author?: string
          cover_storage_path?: string | null
          cover_url?: string | null
          created_at?: string
          description?: string | null
          finished_at?: string | null
          id?: string
          isbn13?: string
          pub_date?: string | null
          publisher?: string | null
          rating?: number | null
          reading_status?: Database["public"]["Enums"]["reading_status"]
          started_at?: string | null
          title?: string
          updated_at?: string
          user_id?: string | null
        }
        Relationships: []
      }
      note_comments: {
        Row: {
          body: string
          created_at: string
          id: string
          note_id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          body: string
          created_at?: string
          id?: string
          note_id: string
          updated_at?: string
          user_id: string
        }
        Update: {
          body?: string
          created_at?: string
          id?: string
          note_id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "note_comments_note_id_fkey"
            columns: ["note_id"]
            isOneToOne: false
            referencedRelation: "notes"
            referencedColumns: ["id"]
          },
        ]
      }
      note_revisions: {
        Row: {
          content: string
          created_at: string
          id: string
          note_id: string
        }
        Insert: {
          content: string
          created_at?: string
          id?: string
          note_id: string
        }
        Update: {
          content?: string
          created_at?: string
          id?: string
          note_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "note_revisions_note_id_fkey"
            columns: ["note_id"]
            isOneToOne: false
            referencedRelation: "notes"
            referencedColumns: ["id"]
          },
        ]
      }
      note_tags: {
        Row: {
          note_id: string
          tag_id: string
        }
        Insert: {
          note_id: string
          tag_id: string
        }
        Update: {
          note_id?: string
          tag_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "note_tags_note_id_fkey"
            columns: ["note_id"]
            isOneToOne: false
            referencedRelation: "notes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "note_tags_tag_id_fkey"
            columns: ["tag_id"]
            isOneToOne: false
            referencedRelation: "tags"
            referencedColumns: ["id"]
          },
        ]
      }
      notes: {
        Row: {
          archived_at: string | null
          content: string | null
          created_at: string
          deleted_at: string | null
          display_id: number
          has_files: boolean
          has_link: boolean
          has_media: boolean
          id: string
          is_deleted: boolean | null
          is_locked: boolean
          is_pinned: boolean
          linear_exported_at: string | null
          linear_issue_key: string | null
          linear_issue_url: string | null
          parent_id: string | null
          pinned_at: string | null
          priority: number
          project_id: string | null
          source: string
          updated_at: string
          user_id: string | null
        }
        Insert: {
          archived_at?: string | null
          content?: string | null
          created_at?: string
          deleted_at?: string | null
          display_id: number
          has_files?: boolean
          has_link?: boolean
          has_media?: boolean
          id?: string
          is_deleted?: boolean | null
          is_locked?: boolean
          is_pinned?: boolean
          linear_exported_at?: string | null
          linear_issue_key?: string | null
          linear_issue_url?: string | null
          parent_id?: string | null
          pinned_at?: string | null
          priority?: number
          project_id?: string | null
          source: string
          updated_at?: string
          user_id?: string | null
        }
        Update: {
          archived_at?: string | null
          content?: string | null
          created_at?: string
          deleted_at?: string | null
          display_id?: number
          has_files?: boolean
          has_link?: boolean
          has_media?: boolean
          id?: string
          is_deleted?: boolean | null
          is_locked?: boolean
          is_pinned?: boolean
          linear_exported_at?: string | null
          linear_issue_key?: string | null
          linear_issue_url?: string | null
          parent_id?: string | null
          pinned_at?: string | null
          priority?: number
          project_id?: string | null
          source?: string
          updated_at?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "notes_parent_id_fkey"
            columns: ["parent_id"]
            isOneToOne: false
            referencedRelation: "notes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notes_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
        ]
      }
      projects: {
        Row: {
          archived_at: string | null
          color: string | null
          created_at: string
          description: string | null
          id: string
          name: string
          updated_at: string
          user_id: string
        }
        Insert: {
          archived_at?: string | null
          color?: string | null
          created_at?: string
          description?: string | null
          id?: string
          name: string
          updated_at?: string
          user_id: string
        }
        Update: {
          archived_at?: string | null
          color?: string | null
          created_at?: string
          description?: string | null
          id?: string
          name?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      tags: {
        Row: {
          created_at: string
          id: string
          last_used_at: string | null
          name: string
          user_id: string | null
        }
        Insert: {
          created_at?: string
          id?: string
          last_used_at?: string | null
          name: string
          user_id?: string | null
        }
        Update: {
          created_at?: string
          id?: string
          last_used_at?: string | null
          name?: string
          user_id?: string | null
        }
        Relationships: []
      }
      user_profiles: {
        Row: {
          created_at: string
          id: string
          mcp_api_key_hash: string | null
          mcp_key_created_at: string | null
          mcp_key_last_used_at: string | null
          mcp_key_prefix: string | null
          pin_hash: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          mcp_api_key_hash?: string | null
          mcp_key_created_at?: string | null
          mcp_key_last_used_at?: string | null
          mcp_key_prefix?: string | null
          pin_hash?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          mcp_api_key_hash?: string | null
          mcp_key_created_at?: string | null
          mcp_key_last_used_at?: string | null
          mcp_key_prefix?: string | null
          pin_hash?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      generate_mcp_api_key: { Args: never; Returns: string }
      get_mcp_api_key: { Args: never; Returns: string }
      get_user_id_by_mcp_key: { Args: { api_key: string }; Returns: string }
      has_note_pin: { Args: never; Returns: boolean }
      mcp_add_comment: {
        Args: { api_key: string; p_body: string; p_note_id: string }
        Returns: Json
      }
      mcp_add_tags_to_note: {
        Args: { api_key: string; p_note_id: string; p_tag_names: string[] }
        Returns: Json
      }
      mcp_archive_note: {
        Args: { api_key: string; p_note_id: string }
        Returns: Json
      }
      mcp_clear_note_export: {
        Args: { api_key: string; p_note_id: string }
        Returns: Json
      }
      mcp_create_attachment: {
        Args: {
          api_key: string
          p_filename: string
          p_mime_type: string
          p_note_id: string
          p_size: number
          p_storage_path: string
          p_type: string
        }
        Returns: Json
      }
      mcp_create_note: {
        Args: {
          api_key: string
          p_content: string
          p_parent_id?: string
          p_tag_names?: string[]
        }
        Returns: Json
      }
      mcp_delete_attachment: {
        Args: { api_key: string; p_attachment_id: string }
        Returns: Json
      }
      mcp_delete_comment: {
        Args: { api_key: string; p_comment_id: string }
        Returns: Json
      }
      mcp_delete_note: {
        Args: { api_key: string; p_note_id: string }
        Returns: Json
      }
      mcp_get_attachment: {
        Args: { api_key: string; p_attachment_id: string }
        Returns: Json
      }
      mcp_get_note: {
        Args: { api_key: string; p_note_id: string }
        Returns: Json
      }
      mcp_get_notes_by_tag: {
        Args: { api_key: string; p_limit?: number; p_tag_name: string }
        Returns: Json
      }
      mcp_list_attachments: {
        Args: { api_key: string; p_note_id: string }
        Returns: Json
      }
      mcp_list_comments: {
        Args: { api_key: string; p_limit?: number; p_note_id: string }
        Returns: Json
      }
      mcp_list_notes: {
        Args: {
          api_key: string
          p_include_archived?: boolean
          p_include_deleted?: boolean
          p_limit?: number
          p_offset?: number
        }
        Returns: Json
      }
      mcp_list_tags: {
        Args: { api_key: string; p_limit?: number }
        Returns: Json
      }
      mcp_remove_tags_from_note: {
        Args: { api_key: string; p_note_id: string; p_tag_names: string[] }
        Returns: Json
      }
      mcp_search_by_date_range: {
        Args: {
          api_key: string
          p_end_date: string
          p_limit?: number
          p_start_date: string
        }
        Returns: Json
      }
      mcp_search_notes: {
        Args: {
          api_key: string
          p_category?: string
          p_limit?: number
          p_query: string
          p_tag_names?: string[]
        }
        Returns: Json
      }
      mcp_set_note_export: {
        Args: {
          api_key: string
          p_issue_key?: string
          p_issue_url: string
          p_note_id: string
        }
        Returns: Json
      }
      mcp_update_note: {
        Args: { api_key: string; p_content: string; p_note_id: string }
        Returns: Json
      }
      mcp_validate_key: { Args: { api_key: string }; Returns: string }
      regenerate_mcp_api_key: { Args: never; Returns: string }
      set_note_pin: { Args: { p_pin: string }; Returns: boolean }
      verify_note_pin: { Args: { p_pin: string }; Returns: boolean }
    }
    Enums: {
      reading_status: "to_read" | "reading" | "completed"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {
      reading_status: ["to_read", "reading", "completed"],
    },
  },
} as const

