export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

export type Database = {
  graphql_public: {
    Tables: {
      [_ in never]: never;
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      graphql: {
        Args: {
          extensions?: Json;
          operationName?: string;
          query?: string;
          variables?: Json;
        };
        Returns: Json;
      };
    };
    Enums: {
      [_ in never]: never;
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
  public: {
    Tables: {
      audit_events: {
        Row: {
          actor_membership_id: string | null;
          created_at: string;
          event_type: string;
          id: string;
          job_id: string | null;
          metadata: Json;
          organization_id: string;
        };
        Insert: {
          actor_membership_id?: string | null;
          created_at?: string;
          event_type: string;
          id?: string;
          job_id?: string | null;
          metadata?: Json;
          organization_id: string;
        };
        Update: {
          actor_membership_id?: string | null;
          created_at?: string;
          event_type?: string;
          id?: string;
          job_id?: string | null;
          metadata?: Json;
          organization_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'audit_actor_same_org_fk';
            columns: ['organization_id', 'actor_membership_id'];
            isOneToOne: false;
            referencedRelation: 'memberships';
            referencedColumns: ['organization_id', 'id'];
          },
          {
            foreignKeyName: 'audit_events_actor_membership_id_fkey';
            columns: ['actor_membership_id'];
            isOneToOne: false;
            referencedRelation: 'memberships';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'audit_events_organization_id_fkey';
            columns: ['organization_id'];
            isOneToOne: false;
            referencedRelation: 'organizations';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'audit_job_same_org_fk';
            columns: ['organization_id', 'job_id'];
            isOneToOne: false;
            referencedRelation: 'jobs';
            referencedColumns: ['organization_id', 'id'];
          }
        ];
      };
      job_context_items: {
        Row: {
          created_at: string;
          id: string;
          job_id: string;
          kind: Database['public']['Enums']['context_kind'];
          label: string;
          organization_id: string;
          sort_order: number;
          source_job_id: string | null;
          text_content: string | null;
          updated_at: string;
          url: string | null;
        };
        Insert: {
          created_at?: string;
          id?: string;
          job_id: string;
          kind: Database['public']['Enums']['context_kind'];
          label: string;
          organization_id: string;
          sort_order?: number;
          source_job_id?: string | null;
          text_content?: string | null;
          updated_at?: string;
          url?: string | null;
        };
        Update: {
          created_at?: string;
          id?: string;
          job_id?: string;
          kind?: Database['public']['Enums']['context_kind'];
          label?: string;
          organization_id?: string;
          sort_order?: number;
          source_job_id?: string | null;
          text_content?: string | null;
          updated_at?: string;
          url?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: 'contexts_job_same_org_fk';
            columns: ['organization_id', 'job_id'];
            isOneToOne: false;
            referencedRelation: 'jobs';
            referencedColumns: ['organization_id', 'id'];
          },
          {
            foreignKeyName: 'contexts_source_same_org_fk';
            columns: ['organization_id', 'source_job_id'];
            isOneToOne: false;
            referencedRelation: 'jobs';
            referencedColumns: ['organization_id', 'id'];
          },
          {
            foreignKeyName: 'job_context_items_job_id_fkey';
            columns: ['job_id'];
            isOneToOne: false;
            referencedRelation: 'jobs';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'job_context_items_source_job_id_fkey';
            columns: ['source_job_id'];
            isOneToOne: false;
            referencedRelation: 'jobs';
            referencedColumns: ['id'];
          }
        ];
      };
      job_files: {
        Row: {
          cleanup_started_at: string | null;
          created_at: string;
          description: string | null;
          id: string;
          job_id: string;
          mime_type: string;
          organization_id: string;
          original_filename: string;
          ready_at: string | null;
          safe_filename: string;
          size_bytes: number;
          storage_path: string;
          upload_status: Database['public']['Enums']['upload_status'];
          uploaded_by_membership_id: string;
        };
        Insert: {
          cleanup_started_at?: string | null;
          created_at?: string;
          description?: string | null;
          id?: string;
          job_id: string;
          mime_type: string;
          organization_id: string;
          original_filename: string;
          ready_at?: string | null;
          safe_filename: string;
          size_bytes: number;
          storage_path: string;
          upload_status?: Database['public']['Enums']['upload_status'];
          uploaded_by_membership_id: string;
        };
        Update: {
          cleanup_started_at?: string | null;
          created_at?: string;
          description?: string | null;
          id?: string;
          job_id?: string;
          mime_type?: string;
          organization_id?: string;
          original_filename?: string;
          ready_at?: string | null;
          safe_filename?: string;
          size_bytes?: number;
          storage_path?: string;
          upload_status?: Database['public']['Enums']['upload_status'];
          uploaded_by_membership_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'job_files_job_id_fkey';
            columns: ['job_id'];
            isOneToOne: false;
            referencedRelation: 'jobs';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'job_files_organization_id_job_id_fkey';
            columns: ['organization_id', 'job_id'];
            isOneToOne: false;
            referencedRelation: 'jobs';
            referencedColumns: ['organization_id', 'id'];
          },
          {
            foreignKeyName: 'job_files_organization_id_uploaded_by_membership_id_fkey';
            columns: ['organization_id', 'uploaded_by_membership_id'];
            isOneToOne: false;
            referencedRelation: 'memberships';
            referencedColumns: ['organization_id', 'id'];
          }
        ];
      };
      job_models: {
        Row: {
          job_id: string;
          model_id: string;
          organization_id: string;
          preference: Database['public']['Enums']['model_preference'];
          sort_order: number;
        };
        Insert: {
          job_id: string;
          model_id: string;
          organization_id: string;
          preference: Database['public']['Enums']['model_preference'];
          sort_order?: number;
        };
        Update: {
          job_id?: string;
          model_id?: string;
          organization_id?: string;
          preference?: Database['public']['Enums']['model_preference'];
          sort_order?: number;
        };
        Relationships: [
          {
            foreignKeyName: 'job_models_organization_id_job_id_fkey';
            columns: ['organization_id', 'job_id'];
            isOneToOne: false;
            referencedRelation: 'jobs';
            referencedColumns: ['organization_id', 'id'];
          },
          {
            foreignKeyName: 'job_models_organization_id_model_id_fkey';
            columns: ['organization_id', 'model_id'];
            isOneToOne: false;
            referencedRelation: 'models';
            referencedColumns: ['organization_id', 'id'];
          }
        ];
      };
      job_payloads: {
        Row: {
          created_at: string;
          current_task: string;
          helper_instructions: string;
          job_id: string;
          output_format: string;
          prompt: string;
          success_criteria: string;
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          current_task: string;
          helper_instructions?: string;
          job_id: string;
          output_format: string;
          prompt?: string;
          success_criteria: string;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          current_task?: string;
          helper_instructions?: string;
          job_id?: string;
          output_format?: string;
          prompt?: string;
          success_criteria?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'job_payloads_job_id_fkey';
            columns: ['job_id'];
            isOneToOne: true;
            referencedRelation: 'jobs';
            referencedColumns: ['id'];
          }
        ];
      };
      jobs: {
        Row: {
          acceptable_models_text: string;
          accepted_submission_id: string | null;
          acknowledgement_version: string | null;
          assigned_to_membership_id: string | null;
          claim_expires_at: string | null;
          claimed_at: string | null;
          created_at: string;
          created_by_membership_id: string;
          data_handling_acknowledged_at: string | null;
          deadline: string | null;
          deletion_pending: boolean;
          deletion_started_at: string | null;
          effort: Database['public']['Enums']['job_effort'];
          id: string;
          listing_summary: string;
          organization_id: string;
          parent_job_id: string | null;
          preferred_model_text: string;
          published_at: string | null;
          requester_action_at: string | null;
          required_tools: string[];
          sensitivity: Database['public']['Enums']['job_sensitivity'];
          sensitivity_notes: string | null;
          status: Database['public']['Enums']['job_status'];
          title: string;
          updated_at: string;
          visibility: Database['public']['Enums']['job_visibility'];
        };
        Insert: {
          acceptable_models_text?: string;
          accepted_submission_id?: string | null;
          acknowledgement_version?: string | null;
          assigned_to_membership_id?: string | null;
          claim_expires_at?: string | null;
          claimed_at?: string | null;
          created_at?: string;
          created_by_membership_id: string;
          data_handling_acknowledged_at?: string | null;
          deadline?: string | null;
          deletion_pending?: boolean;
          deletion_started_at?: string | null;
          effort?: Database['public']['Enums']['job_effort'];
          id?: string;
          listing_summary: string;
          organization_id: string;
          parent_job_id?: string | null;
          preferred_model_text?: string;
          published_at?: string | null;
          requester_action_at?: string | null;
          required_tools?: string[];
          sensitivity?: Database['public']['Enums']['job_sensitivity'];
          sensitivity_notes?: string | null;
          status?: Database['public']['Enums']['job_status'];
          title: string;
          updated_at?: string;
          visibility?: Database['public']['Enums']['job_visibility'];
        };
        Update: {
          acceptable_models_text?: string;
          accepted_submission_id?: string | null;
          acknowledgement_version?: string | null;
          assigned_to_membership_id?: string | null;
          claim_expires_at?: string | null;
          claimed_at?: string | null;
          created_at?: string;
          created_by_membership_id?: string;
          data_handling_acknowledged_at?: string | null;
          deadline?: string | null;
          deletion_pending?: boolean;
          deletion_started_at?: string | null;
          effort?: Database['public']['Enums']['job_effort'];
          id?: string;
          listing_summary?: string;
          organization_id?: string;
          parent_job_id?: string | null;
          preferred_model_text?: string;
          published_at?: string | null;
          requester_action_at?: string | null;
          required_tools?: string[];
          sensitivity?: Database['public']['Enums']['job_sensitivity'];
          sensitivity_notes?: string | null;
          status?: Database['public']['Enums']['job_status'];
          title?: string;
          updated_at?: string;
          visibility?: Database['public']['Enums']['job_visibility'];
        };
        Relationships: [
          {
            foreignKeyName: 'accepted_submission_fk';
            columns: ['id', 'accepted_submission_id'];
            isOneToOne: false;
            referencedRelation: 'submissions';
            referencedColumns: ['job_id', 'id'];
          },
          {
            foreignKeyName: 'jobs_organization_id_assigned_to_membership_id_fkey';
            columns: ['organization_id', 'assigned_to_membership_id'];
            isOneToOne: false;
            referencedRelation: 'memberships';
            referencedColumns: ['organization_id', 'id'];
          },
          {
            foreignKeyName: 'jobs_organization_id_created_by_membership_id_fkey';
            columns: ['organization_id', 'created_by_membership_id'];
            isOneToOne: false;
            referencedRelation: 'memberships';
            referencedColumns: ['organization_id', 'id'];
          },
          {
            foreignKeyName: 'jobs_organization_id_fkey';
            columns: ['organization_id'];
            isOneToOne: false;
            referencedRelation: 'organizations';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'jobs_parent_job_id_fkey';
            columns: ['parent_job_id'];
            isOneToOne: false;
            referencedRelation: 'jobs';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'jobs_parent_same_org_fk';
            columns: ['organization_id', 'parent_job_id'];
            isOneToOne: false;
            referencedRelation: 'jobs';
            referencedColumns: ['organization_id', 'id'];
          }
        ];
      };
      member_models: {
        Row: {
          created_at: string;
          membership_id: string;
          model_id: string;
          organization_id: string;
        };
        Insert: {
          created_at?: string;
          membership_id: string;
          model_id: string;
          organization_id: string;
        };
        Update: {
          created_at?: string;
          membership_id?: string;
          model_id?: string;
          organization_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'member_models_organization_id_membership_id_fkey';
            columns: ['organization_id', 'membership_id'];
            isOneToOne: false;
            referencedRelation: 'memberships';
            referencedColumns: ['organization_id', 'id'];
          },
          {
            foreignKeyName: 'member_models_organization_id_model_id_fkey';
            columns: ['organization_id', 'model_id'];
            isOneToOne: false;
            referencedRelation: 'models';
            referencedColumns: ['organization_id', 'id'];
          }
        ];
      };
      memberships: {
        Row: {
          account_deletion_started_at: string | null;
          active: boolean;
          bio: string | null;
          capabilities: string[];
          claimed_at: string | null;
          claimed_user_id: string | null;
          created_at: string;
          deleted_at: string | null;
          display_name: string | null;
          id: string;
          invited_email: string;
          notification_preferences: Json;
          organization_id: string;
          role: Database['public']['Enums']['member_role'];
          updated_at: string;
          user_id: string | null;
        };
        Insert: {
          account_deletion_started_at?: string | null;
          active?: boolean;
          bio?: string | null;
          capabilities?: string[];
          claimed_at?: string | null;
          claimed_user_id?: string | null;
          created_at?: string;
          deleted_at?: string | null;
          display_name?: string | null;
          id?: string;
          invited_email: string;
          notification_preferences?: Json;
          organization_id: string;
          role?: Database['public']['Enums']['member_role'];
          updated_at?: string;
          user_id?: string | null;
        };
        Update: {
          account_deletion_started_at?: string | null;
          active?: boolean;
          bio?: string | null;
          capabilities?: string[];
          claimed_at?: string | null;
          claimed_user_id?: string | null;
          created_at?: string;
          deleted_at?: string | null;
          display_name?: string | null;
          id?: string;
          invited_email?: string;
          notification_preferences?: Json;
          organization_id?: string;
          role?: Database['public']['Enums']['member_role'];
          updated_at?: string;
          user_id?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: 'memberships_organization_id_fkey';
            columns: ['organization_id'];
            isOneToOne: false;
            referencedRelation: 'organizations';
            referencedColumns: ['id'];
          }
        ];
      };
      models: {
        Row: {
          active: boolean;
          created_at: string;
          display_name: string;
          id: string;
          organization_id: string;
          provider: string;
          sort_order: number;
          updated_at: string;
        };
        Insert: {
          active?: boolean;
          created_at?: string;
          display_name: string;
          id?: string;
          organization_id: string;
          provider: string;
          sort_order?: number;
          updated_at?: string;
        };
        Update: {
          active?: boolean;
          created_at?: string;
          display_name?: string;
          id?: string;
          organization_id?: string;
          provider?: string;
          sort_order?: number;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'models_organization_id_fkey';
            columns: ['organization_id'];
            isOneToOne: false;
            referencedRelation: 'organizations';
            referencedColumns: ['id'];
          }
        ];
      };
      notifications: {
        Row: {
          created_at: string;
          id: string;
          job_id: string | null;
          message: string;
          organization_id: string;
          read_at: string | null;
          recipient_membership_id: string;
          type: string;
        };
        Insert: {
          created_at?: string;
          id?: string;
          job_id?: string | null;
          message: string;
          organization_id: string;
          read_at?: string | null;
          recipient_membership_id: string;
          type: string;
        };
        Update: {
          created_at?: string;
          id?: string;
          job_id?: string | null;
          message?: string;
          organization_id?: string;
          read_at?: string | null;
          recipient_membership_id?: string;
          type?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'notifications_job_id_fkey';
            columns: ['job_id'];
            isOneToOne: false;
            referencedRelation: 'jobs';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'notifications_job_same_org_fk';
            columns: ['organization_id', 'job_id'];
            isOneToOne: false;
            referencedRelation: 'jobs';
            referencedColumns: ['organization_id', 'id'];
          },
          {
            foreignKeyName: 'notifications_organization_id_fkey';
            columns: ['organization_id'];
            isOneToOne: false;
            referencedRelation: 'organizations';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'notifications_organization_id_recipient_membership_id_fkey';
            columns: ['organization_id', 'recipient_membership_id'];
            isOneToOne: false;
            referencedRelation: 'memberships';
            referencedColumns: ['organization_id', 'id'];
          }
        ];
      };
      organizations: {
        Row: {
          created_at: string;
          id: string;
          name: string;
          slug: string;
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          id?: string;
          name: string;
          slug: string;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          id?: string;
          name?: string;
          slug?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      profile_photos: {
        Row: {
          cleanup_started_at: string | null;
          created_at: string;
          id: string;
          membership_id: string;
          mime_type: string;
          organization_id: string;
          original_filename: string;
          ready_at: string | null;
          safe_filename: string;
          size_bytes: number;
          storage_path: string;
          upload_status: Database['public']['Enums']['upload_status'];
        };
        Insert: {
          cleanup_started_at?: string | null;
          created_at?: string;
          id?: string;
          membership_id: string;
          mime_type: string;
          organization_id: string;
          original_filename: string;
          ready_at?: string | null;
          safe_filename: string;
          size_bytes: number;
          storage_path: string;
          upload_status?: Database['public']['Enums']['upload_status'];
        };
        Update: {
          cleanup_started_at?: string | null;
          created_at?: string;
          id?: string;
          membership_id?: string;
          mime_type?: string;
          organization_id?: string;
          original_filename?: string;
          ready_at?: string | null;
          safe_filename?: string;
          size_bytes?: number;
          storage_path?: string;
          upload_status?: Database['public']['Enums']['upload_status'];
        };
        Relationships: [
          {
            foreignKeyName: 'profile_photos_organization_id_membership_id_fkey';
            columns: ['organization_id', 'membership_id'];
            isOneToOne: false;
            referencedRelation: 'memberships';
            referencedColumns: ['organization_id', 'id'];
          }
        ];
      };
      revision_requests: {
        Row: {
          created_at: string;
          id: string;
          instructions: string;
          job_id: string;
          organization_id: string;
          requested_by_membership_id: string;
          resolved_at: string | null;
          resolved_by_submission_id: string | null;
          submission_id: string;
        };
        Insert: {
          created_at?: string;
          id?: string;
          instructions: string;
          job_id: string;
          organization_id: string;
          requested_by_membership_id: string;
          resolved_at?: string | null;
          resolved_by_submission_id?: string | null;
          submission_id: string;
        };
        Update: {
          created_at?: string;
          id?: string;
          instructions?: string;
          job_id?: string;
          organization_id?: string;
          requested_by_membership_id?: string;
          resolved_at?: string | null;
          resolved_by_submission_id?: string | null;
          submission_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'revision_requests_job_id_fkey';
            columns: ['job_id'];
            isOneToOne: false;
            referencedRelation: 'jobs';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'revision_requests_job_id_resolved_by_submission_id_fkey';
            columns: ['job_id', 'resolved_by_submission_id'];
            isOneToOne: false;
            referencedRelation: 'submissions';
            referencedColumns: ['job_id', 'id'];
          },
          {
            foreignKeyName: 'revision_requests_job_id_submission_id_fkey';
            columns: ['job_id', 'submission_id'];
            isOneToOne: false;
            referencedRelation: 'submissions';
            referencedColumns: ['job_id', 'id'];
          },
          {
            foreignKeyName: 'revision_requests_requested_by_membership_id_fkey';
            columns: ['requested_by_membership_id'];
            isOneToOne: false;
            referencedRelation: 'memberships';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'revisions_job_same_org_fk';
            columns: ['organization_id', 'job_id'];
            isOneToOne: false;
            referencedRelation: 'jobs';
            referencedColumns: ['organization_id', 'id'];
          },
          {
            foreignKeyName: 'revisions_requester_same_org_fk';
            columns: ['organization_id', 'requested_by_membership_id'];
            isOneToOne: false;
            referencedRelation: 'memberships';
            referencedColumns: ['organization_id', 'id'];
          }
        ];
      };
      submission_files: {
        Row: {
          cleanup_started_at: string | null;
          created_at: string;
          description: string | null;
          id: string;
          job_id: string;
          mime_type: string;
          organization_id: string;
          original_filename: string;
          ready_at: string | null;
          safe_filename: string;
          size_bytes: number;
          storage_path: string;
          submission_id: string;
          upload_status: Database['public']['Enums']['upload_status'];
          uploaded_by_membership_id: string;
        };
        Insert: {
          cleanup_started_at?: string | null;
          created_at?: string;
          description?: string | null;
          id?: string;
          job_id: string;
          mime_type: string;
          organization_id: string;
          original_filename: string;
          ready_at?: string | null;
          safe_filename: string;
          size_bytes: number;
          storage_path: string;
          submission_id: string;
          upload_status?: Database['public']['Enums']['upload_status'];
          uploaded_by_membership_id: string;
        };
        Update: {
          cleanup_started_at?: string | null;
          created_at?: string;
          description?: string | null;
          id?: string;
          job_id?: string;
          mime_type?: string;
          organization_id?: string;
          original_filename?: string;
          ready_at?: string | null;
          safe_filename?: string;
          size_bytes?: number;
          storage_path?: string;
          submission_id?: string;
          upload_status?: Database['public']['Enums']['upload_status'];
          uploaded_by_membership_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'submission_files_job_id_submission_id_fkey';
            columns: ['job_id', 'submission_id'];
            isOneToOne: false;
            referencedRelation: 'submissions';
            referencedColumns: ['job_id', 'id'];
          },
          {
            foreignKeyName: 'submission_files_organization_id_job_id_fkey';
            columns: ['organization_id', 'job_id'];
            isOneToOne: false;
            referencedRelation: 'jobs';
            referencedColumns: ['organization_id', 'id'];
          },
          {
            foreignKeyName: 'submission_files_organization_id_uploaded_by_membership_id_fkey';
            columns: ['organization_id', 'uploaded_by_membership_id'];
            isOneToOne: false;
            referencedRelation: 'memberships';
            referencedColumns: ['organization_id', 'id'];
          }
        ];
      };
      submissions: {
        Row: {
          created_at: string;
          edit_locked_at: string | null;
          edited_at: string | null;
          id: string;
          job_id: string;
          model_used_text: string;
          notes: string | null;
          organization_id: string;
          reasoning_effort: string | null;
          reasoning_effort_other: string | null;
          response_text: string;
          revision_number: number | null;
          status: Database['public']['Enums']['submission_status'];
          submitted_at: string | null;
          submitted_by_membership_id: string;
          tools_used: string[];
        };
        Insert: {
          created_at?: string;
          edit_locked_at?: string | null;
          edited_at?: string | null;
          id?: string;
          job_id: string;
          model_used_text?: string;
          notes?: string | null;
          organization_id: string;
          reasoning_effort?: string | null;
          reasoning_effort_other?: string | null;
          response_text?: string;
          revision_number?: number | null;
          status?: Database['public']['Enums']['submission_status'];
          submitted_at?: string | null;
          submitted_by_membership_id: string;
          tools_used?: string[];
        };
        Update: {
          created_at?: string;
          edit_locked_at?: string | null;
          edited_at?: string | null;
          id?: string;
          job_id?: string;
          model_used_text?: string;
          notes?: string | null;
          organization_id?: string;
          reasoning_effort?: string | null;
          reasoning_effort_other?: string | null;
          response_text?: string;
          revision_number?: number | null;
          status?: Database['public']['Enums']['submission_status'];
          submitted_at?: string | null;
          submitted_by_membership_id?: string;
          tools_used?: string[];
        };
        Relationships: [
          {
            foreignKeyName: 'submissions_job_id_fkey';
            columns: ['job_id'];
            isOneToOne: false;
            referencedRelation: 'jobs';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'submissions_organization_id_job_id_fkey';
            columns: ['organization_id', 'job_id'];
            isOneToOne: false;
            referencedRelation: 'jobs';
            referencedColumns: ['organization_id', 'id'];
          },
          {
            foreignKeyName: 'submissions_organization_id_submitted_by_membership_id_fkey';
            columns: ['organization_id', 'submitted_by_membership_id'];
            isOneToOne: false;
            referencedRelation: 'memberships';
            referencedColumns: ['organization_id', 'id'];
          }
        ];
      };
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      accept_job: { Args: { p_job_id: string }; Returns: undefined };
      admin_delete_unclaimed_invitation: {
        Args: { p_membership_id: string; p_organization_id: string };
        Returns: undefined;
      };
      admin_memberships: {
        Args: { p_organization_id: string };
        Returns: {
          active: boolean;
          claimed: boolean;
          display_name: string;
          id: string;
          invited_email: string;
          role: Database['public']['Enums']['member_role'];
        }[];
      };
      admin_update_membership: {
        Args: {
          p_active: boolean;
          p_membership_id: string;
          p_organization_id: string;
          p_role: Database['public']['Enums']['member_role'];
        };
        Returns: undefined;
      };
      admin_upsert_membership: {
        Args: {
          p_email: string;
          p_organization_id: string;
          p_role?: Database['public']['Enums']['member_role'];
        };
        Returns: string;
      };
      begin_account_deletion: {
        Args: never;
        Returns: {
          bucket_id: string;
          storage_path: string;
        }[];
      };
      begin_job_deletion: {
        Args: { p_job_id: string };
        Returns: {
          file_id: string;
          kind: string;
          storage_path: string;
        }[];
      };
      cancel_job: { Args: { p_job_id: string }; Returns: undefined };
      claim_available_memberships: {
        Args: never;
        Returns: {
          membership_id: string;
          organization_id: string;
        }[];
      };
      claim_job: { Args: { p_job_id: string }; Returns: undefined };
      create_draft_job: {
        Args: { p_input: Json; p_organization_id: string };
        Returns: string;
      };
      create_follow_up_draft: { Args: { p_job_id: string }; Returns: string };
      create_submission_draft: { Args: { p_job_id: string }; Returns: string };
      dashboard_jobs: {
        Args: { p_organization_id: string; p_tab?: string };
        Returns: {
          claim_expires_at: string;
          deadline: string;
          effort: Database['public']['Enums']['job_effort'];
          id: string;
          listing_summary: string;
          preferred_model: string;
          requester_name: string;
          required_tools: string[];
          sensitivity: Database['public']['Enums']['job_sensitivity'];
          status: Database['public']['Enums']['job_status'];
          title: string;
          visibility: Database['public']['Enums']['job_visibility'];
        }[];
      };
      delete_file_record: {
        Args: { p_file_id: string; p_kind: string };
        Returns: undefined;
      };
      delete_job_after_storage_cleanup: {
        Args: { p_job_id: string };
        Returns: undefined;
      };
      delete_own_account: { Args: never; Returns: undefined };
      delete_profile_photo_record: {
        Args: { p_photo_id: string };
        Returns: undefined;
      };
      edit_submitted_result: {
        Args: {
          p_job_id: string;
          p_model_used_text: string;
          p_notes: string;
          p_reasoning_effort: string;
          p_reasoning_effort_other: string;
          p_response_text: string;
        };
        Returns: undefined;
      };
      extend_claim: { Args: { p_job_id: string }; Returns: undefined };
      file_cleanup_info: {
        Args: { p_file_id: string; p_kind: string };
        Returns: {
          mime_type: string;
          original_filename: string;
          size_bytes: number;
          storage_path: string;
        }[];
      };
      file_download_info: {
        Args: { p_file_id: string; p_kind: string };
        Returns: {
          mime_type: string;
          original_filename: string;
          size_bytes: number;
          storage_path: string;
        }[];
      };
      finalize_job_file: { Args: { p_file_id: string }; Returns: undefined };
      finalize_profile_photo: {
        Args: { p_photo_id: string };
        Returns: undefined;
      };
      finalize_submission_file: {
        Args: { p_file_id: string };
        Returns: undefined;
      };
      job_workspace: { Args: { p_job_id: string }; Returns: Json };
      mark_notification_read: {
        Args: { p_notification_id: string };
        Returns: undefined;
      };
      my_active_memberships: {
        Args: never;
        Returns: {
          bio: string;
          capabilities: string[];
          display_name: string;
          membership_id: string;
          notification_preferences: Json;
          organization_id: string;
          organization_name: string;
          role: Database['public']['Enums']['member_role'];
        }[];
      };
      profile_photo_cleanup_info: {
        Args: { p_photo_id: string };
        Returns: {
          mime_type: string;
          original_filename: string;
          size_bytes: number;
          storage_path: string;
        }[];
      };
      profile_photo_download_info: {
        Args: { p_membership_id: string };
        Returns: {
          mime_type: string;
          original_filename: string;
          size_bytes: number;
          storage_path: string;
        }[];
      };
      publish_job: { Args: { p_job_id: string }; Returns: undefined };
      release_job: { Args: { p_job_id: string }; Returns: undefined };
      reopen_job: { Args: { p_job_id: string }; Returns: undefined };
      request_revision: {
        Args: { p_instructions: string; p_job_id: string };
        Returns: undefined;
      };
      reserve_job_file: {
        Args: {
          p_description?: string;
          p_filename: string;
          p_job_id: string;
          p_mime_type: string;
          p_size_bytes: number;
        };
        Returns: {
          id: string;
          storage_path: string;
        }[];
      };
      reserve_profile_photo: {
        Args: {
          p_filename: string;
          p_mime_type: string;
          p_organization_id: string;
          p_size_bytes: number;
        };
        Returns: {
          id: string;
          storage_path: string;
        }[];
      };
      reserve_submission_file: {
        Args: {
          p_description?: string;
          p_filename: string;
          p_job_id: string;
          p_mime_type: string;
          p_size_bytes: number;
        };
        Returns: {
          id: string;
          storage_path: string;
          submission_id: string;
        }[];
      };
      submit_result: {
        Args: {
          p_job_id: string;
          p_model_used_text: string;
          p_notes: string;
          p_reasoning_effort: string;
          p_reasoning_effort_other: string;
          p_response_text: string;
        };
        Returns: undefined;
      };
      update_and_publish_job: {
        Args: { p_input: Json; p_job_id: string };
        Returns: undefined;
      };
      update_draft_job: {
        Args: { p_input: Json; p_job_id: string };
        Returns: undefined;
      };
      update_profile: {
        Args: {
          p_bio: string;
          p_display_name: string;
          p_model_ids: string[];
          p_organization_id: string;
          p_preferences: Json;
        };
        Returns: undefined;
      };
    };
    Enums: {
      context_kind: 'inline_text' | 'shared_chat' | 'external_link' | 'previous_job';
      job_effort: 'quick' | 'medium' | 'heavy';
      job_sensitivity: 'general' | 'unpublished' | 'collaborator' | 'other';
      job_status: 'draft' | 'open' | 'claimed' | 'submitted' | 'revision_requested' | 'accepted' | 'cancelled';
      job_visibility: 'lab' | 'claimed_only';
      member_role: 'member' | 'admin';
      model_preference: 'preferred' | 'acceptable';
      submission_status: 'draft' | 'submitted';
      upload_status: 'pending' | 'ready';
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
  storage: {
    Tables: {
      buckets: {
        Row: {
          allowed_mime_types: string[] | null;
          avif_autodetection: boolean | null;
          created_at: string | null;
          file_size_limit: number | null;
          id: string;
          name: string;
          owner: string | null;
          owner_id: string | null;
          public: boolean | null;
          type: Database['storage']['Enums']['buckettype'];
          updated_at: string | null;
          versioning_status: string;
        };
        Insert: {
          allowed_mime_types?: string[] | null;
          avif_autodetection?: boolean | null;
          created_at?: string | null;
          file_size_limit?: number | null;
          id: string;
          name: string;
          owner?: string | null;
          owner_id?: string | null;
          public?: boolean | null;
          type?: Database['storage']['Enums']['buckettype'];
          updated_at?: string | null;
          versioning_status?: string;
        };
        Update: {
          allowed_mime_types?: string[] | null;
          avif_autodetection?: boolean | null;
          created_at?: string | null;
          file_size_limit?: number | null;
          id?: string;
          name?: string;
          owner?: string | null;
          owner_id?: string | null;
          public?: boolean | null;
          type?: Database['storage']['Enums']['buckettype'];
          updated_at?: string | null;
          versioning_status?: string;
        };
        Relationships: [];
      };
      buckets_analytics: {
        Row: {
          created_at: string;
          deleted_at: string | null;
          format: string;
          id: string;
          name: string;
          type: Database['storage']['Enums']['buckettype'];
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          deleted_at?: string | null;
          format?: string;
          id?: string;
          name: string;
          type?: Database['storage']['Enums']['buckettype'];
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          deleted_at?: string | null;
          format?: string;
          id?: string;
          name?: string;
          type?: Database['storage']['Enums']['buckettype'];
          updated_at?: string;
        };
        Relationships: [];
      };
      buckets_vectors: {
        Row: {
          created_at: string;
          id: string;
          type: Database['storage']['Enums']['buckettype'];
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          id: string;
          type?: Database['storage']['Enums']['buckettype'];
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          id?: string;
          type?: Database['storage']['Enums']['buckettype'];
          updated_at?: string;
        };
        Relationships: [];
      };
      iceberg_namespaces: {
        Row: {
          bucket_name: string;
          catalog_id: string;
          created_at: string;
          id: string;
          metadata: Json;
          name: string;
          updated_at: string;
        };
        Insert: {
          bucket_name: string;
          catalog_id: string;
          created_at?: string;
          id?: string;
          metadata?: Json;
          name: string;
          updated_at?: string;
        };
        Update: {
          bucket_name?: string;
          catalog_id?: string;
          created_at?: string;
          id?: string;
          metadata?: Json;
          name?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'iceberg_namespaces_catalog_id_fkey';
            columns: ['catalog_id'];
            isOneToOne: false;
            referencedRelation: 'buckets_analytics';
            referencedColumns: ['id'];
          }
        ];
      };
      iceberg_tables: {
        Row: {
          bucket_name: string;
          catalog_id: string;
          created_at: string;
          id: string;
          location: string;
          name: string;
          namespace_id: string;
          remote_table_id: string | null;
          shard_id: string | null;
          shard_key: string | null;
          updated_at: string;
        };
        Insert: {
          bucket_name: string;
          catalog_id: string;
          created_at?: string;
          id?: string;
          location: string;
          name: string;
          namespace_id: string;
          remote_table_id?: string | null;
          shard_id?: string | null;
          shard_key?: string | null;
          updated_at?: string;
        };
        Update: {
          bucket_name?: string;
          catalog_id?: string;
          created_at?: string;
          id?: string;
          location?: string;
          name?: string;
          namespace_id?: string;
          remote_table_id?: string | null;
          shard_id?: string | null;
          shard_key?: string | null;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'iceberg_tables_catalog_id_fkey';
            columns: ['catalog_id'];
            isOneToOne: false;
            referencedRelation: 'buckets_analytics';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'iceberg_tables_namespace_id_fkey';
            columns: ['namespace_id'];
            isOneToOne: false;
            referencedRelation: 'iceberg_namespaces';
            referencedColumns: ['id'];
          }
        ];
      };
      migrations: {
        Row: {
          executed_at: string | null;
          hash: string;
          id: number;
          name: string;
        };
        Insert: {
          executed_at?: string | null;
          hash: string;
          id: number;
          name: string;
        };
        Update: {
          executed_at?: string | null;
          hash?: string;
          id?: number;
          name?: string;
        };
        Relationships: [];
      };
      objects: {
        Row: {
          archived_at: string | null;
          bucket_id: string | null;
          created_at: string | null;
          id: string;
          is_delete_marker: boolean;
          is_versioned: boolean;
          last_accessed_at: string | null;
          metadata: Json | null;
          name: string | null;
          owner: string | null;
          owner_id: string | null;
          path_tokens: string[] | null;
          updated_at: string | null;
          user_metadata: Json | null;
          version: string | null;
        };
        Insert: {
          archived_at?: string | null;
          bucket_id?: string | null;
          created_at?: string | null;
          id?: string;
          is_delete_marker?: boolean;
          is_versioned?: boolean;
          last_accessed_at?: string | null;
          metadata?: Json | null;
          name?: string | null;
          owner?: string | null;
          owner_id?: string | null;
          path_tokens?: string[] | null;
          updated_at?: string | null;
          user_metadata?: Json | null;
          version?: string | null;
        };
        Update: {
          archived_at?: string | null;
          bucket_id?: string | null;
          created_at?: string | null;
          id?: string;
          is_delete_marker?: boolean;
          is_versioned?: boolean;
          last_accessed_at?: string | null;
          metadata?: Json | null;
          name?: string | null;
          owner?: string | null;
          owner_id?: string | null;
          path_tokens?: string[] | null;
          updated_at?: string | null;
          user_metadata?: Json | null;
          version?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: 'objects_bucketId_fkey';
            columns: ['bucket_id'];
            isOneToOne: false;
            referencedRelation: 'buckets';
            referencedColumns: ['id'];
          }
        ];
      };
      s3_multipart_uploads: {
        Row: {
          bucket_id: string;
          created_at: string;
          id: string;
          in_progress_size: number;
          key: string;
          metadata: Json | null;
          owner_id: string | null;
          upload_signature: string;
          user_metadata: Json | null;
          version: string;
        };
        Insert: {
          bucket_id: string;
          created_at?: string;
          id: string;
          in_progress_size?: number;
          key: string;
          metadata?: Json | null;
          owner_id?: string | null;
          upload_signature: string;
          user_metadata?: Json | null;
          version: string;
        };
        Update: {
          bucket_id?: string;
          created_at?: string;
          id?: string;
          in_progress_size?: number;
          key?: string;
          metadata?: Json | null;
          owner_id?: string | null;
          upload_signature?: string;
          user_metadata?: Json | null;
          version?: string;
        };
        Relationships: [
          {
            foreignKeyName: 's3_multipart_uploads_bucket_id_fkey';
            columns: ['bucket_id'];
            isOneToOne: false;
            referencedRelation: 'buckets';
            referencedColumns: ['id'];
          }
        ];
      };
      s3_multipart_uploads_parts: {
        Row: {
          bucket_id: string;
          created_at: string;
          etag: string;
          id: string;
          key: string;
          owner_id: string | null;
          part_number: number;
          size: number;
          upload_id: string;
          version: string;
        };
        Insert: {
          bucket_id: string;
          created_at?: string;
          etag: string;
          id?: string;
          key: string;
          owner_id?: string | null;
          part_number: number;
          size?: number;
          upload_id: string;
          version: string;
        };
        Update: {
          bucket_id?: string;
          created_at?: string;
          etag?: string;
          id?: string;
          key?: string;
          owner_id?: string | null;
          part_number?: number;
          size?: number;
          upload_id?: string;
          version?: string;
        };
        Relationships: [
          {
            foreignKeyName: 's3_multipart_uploads_parts_bucket_id_fkey';
            columns: ['bucket_id'];
            isOneToOne: false;
            referencedRelation: 'buckets';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 's3_multipart_uploads_parts_upload_id_fkey';
            columns: ['upload_id'];
            isOneToOne: false;
            referencedRelation: 's3_multipart_uploads';
            referencedColumns: ['id'];
          }
        ];
      };
      vector_indexes: {
        Row: {
          bucket_id: string;
          created_at: string;
          data_type: string;
          dimension: number;
          distance_metric: string;
          id: string;
          metadata_configuration: Json | null;
          name: string;
          updated_at: string;
        };
        Insert: {
          bucket_id: string;
          created_at?: string;
          data_type: string;
          dimension: number;
          distance_metric: string;
          id?: string;
          metadata_configuration?: Json | null;
          name: string;
          updated_at?: string;
        };
        Update: {
          bucket_id?: string;
          created_at?: string;
          data_type?: string;
          dimension?: number;
          distance_metric?: string;
          id?: string;
          metadata_configuration?: Json | null;
          name?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'vector_indexes_bucket_id_fkey';
            columns: ['bucket_id'];
            isOneToOne: false;
            referencedRelation: 'buckets_vectors';
            referencedColumns: ['id'];
          }
        ];
      };
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      allow_any_operation: {
        Args: { expected_operations: string[] };
        Returns: boolean;
      };
      allow_only_operation: {
        Args: { expected_operation: string };
        Returns: boolean;
      };
      can_insert_object: {
        Args: { bucketid: string; metadata: Json; name: string; owner: string };
        Returns: undefined;
      };
      extension: { Args: { name: string }; Returns: string };
      filename: { Args: { name: string }; Returns: string };
      foldername: { Args: { name: string }; Returns: string[] };
      get_common_prefix: {
        Args: { p_delimiter: string; p_key: string; p_prefix: string };
        Returns: string;
      };
      get_size_by_bucket: {
        Args: never;
        Returns: {
          bucket_id: string;
          size: number;
        }[];
      };
      list_multipart_uploads_with_delimiter: {
        Args: {
          bucket_id: string;
          delimiter_param: string;
          max_keys?: number;
          next_key_token?: string;
          next_upload_token?: string;
          prefix_param: string;
        };
        Returns: {
          created_at: string;
          id: string;
          key: string;
        }[];
      };
      list_objects_with_delimiter: {
        Args: {
          _bucket_id: string;
          delimiter_param: string;
          max_keys?: number;
          next_token?: string;
          prefix_param: string;
          sort_order?: string;
          start_after?: string;
        };
        Returns: {
          created_at: string;
          id: string;
          last_accessed_at: string;
          metadata: Json;
          name: string;
          updated_at: string;
        }[];
      };
      operation: { Args: never; Returns: string };
      search: {
        Args: {
          bucketname: string;
          levels?: number;
          limits?: number;
          offsets?: number;
          prefix: string;
          search?: string;
          sortcolumn?: string;
          sortorder?: string;
        };
        Returns: {
          created_at: string;
          id: string;
          last_accessed_at: string;
          metadata: Json;
          name: string;
          updated_at: string;
        }[];
      };
      search_by_timestamp: {
        Args: {
          p_bucket_id: string;
          p_level: number;
          p_limit: number;
          p_prefix: string;
          p_sort_column: string;
          p_sort_column_after: string;
          p_sort_order: string;
          p_start_after: string;
        };
        Returns: {
          created_at: string;
          id: string;
          key: string;
          last_accessed_at: string;
          metadata: Json;
          name: string;
          updated_at: string;
        }[];
      };
      search_v2: {
        Args: {
          bucket_name: string;
          levels?: number;
          limits?: number;
          prefix: string;
          sort_column?: string;
          sort_column_after?: string;
          sort_order?: string;
          start_after?: string;
        };
        Returns: {
          created_at: string;
          id: string;
          key: string;
          last_accessed_at: string;
          metadata: Json;
          name: string;
          updated_at: string;
        }[];
      };
    };
    Enums: {
      buckettype: 'STANDARD' | 'ANALYTICS' | 'VECTOR';
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
};

type DatabaseWithoutInternals = Omit<Database, '__InternalSupabase'>;

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, 'public'>];

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    keyof (DefaultSchema['Tables'] & DefaultSchema['Views']) | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables'] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Views'])
    : never) = never
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables'] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Views'])[TableName] extends {
      Row: infer R;
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema['Tables'] & DefaultSchema['Views'])
    ? (DefaultSchema['Tables'] & DefaultSchema['Views'])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R;
      }
      ? R
      : never
    : never;

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends keyof DefaultSchema['Tables'] | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables']
    : never) = never
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables'][TableName] extends {
      Insert: infer I;
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema['Tables']
    ? DefaultSchema['Tables'][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I;
      }
      ? I
      : never
    : never;

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends keyof DefaultSchema['Tables'] | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables']
    : never) = never
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables'][TableName] extends {
      Update: infer U;
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema['Tables']
    ? DefaultSchema['Tables'][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U;
      }
      ? U
      : never
    : never;

export type Enums<
  DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema['Enums'] | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions['schema']]['Enums']
    : never) = never
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions['schema']]['Enums'][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema['Enums']
    ? DefaultSchema['Enums'][DefaultSchemaEnumNameOrOptions]
    : never;

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    keyof DefaultSchema['CompositeTypes'] | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions['schema']]['CompositeTypes']
    : never) = never
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions['schema']]['CompositeTypes'][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema['CompositeTypes']
    ? DefaultSchema['CompositeTypes'][PublicCompositeTypeNameOrOptions]
    : never;

export const Constants = {
  graphql_public: {
    Enums: {}
  },
  public: {
    Enums: {
      context_kind: ['inline_text', 'shared_chat', 'external_link', 'previous_job'],
      job_effort: ['quick', 'medium', 'heavy'],
      job_sensitivity: ['general', 'unpublished', 'collaborator', 'other'],
      job_status: ['draft', 'open', 'claimed', 'submitted', 'revision_requested', 'accepted', 'cancelled'],
      job_visibility: ['lab', 'claimed_only'],
      member_role: ['member', 'admin'],
      model_preference: ['preferred', 'acceptable'],
      submission_status: ['draft', 'submitted'],
      upload_status: ['pending', 'ready']
    }
  },
  storage: {
    Enums: {
      buckettype: ['STANDARD', 'ANALYTICS', 'VECTOR']
    }
  }
} as const;
