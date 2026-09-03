import type { SupabaseClient } from '@supabase/supabase-js';
declare global {
  namespace App {
    interface Locals {
      supabase: SupabaseClient;
      userId: string | null;
      safeGetClaims: () => Promise<string | null>;
    }
  }
}
export {};
