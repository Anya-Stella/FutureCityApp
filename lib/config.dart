class SupabaseConfig {
  SupabaseConfig._();

  // TODO: Replace with your actual Supabase URL and Anon Key
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://eoykssuwusxhnbbcfqgl.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVveWtzc3V3dXN4aG5iYmNmcWdsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE5NjA5NTIsImV4cCI6MjA5NzUzNjk1Mn0.wdCKuRdoz3d6jWqYBQMkfdBu293yCTlbDIQBQkDKb58',
  );
}
