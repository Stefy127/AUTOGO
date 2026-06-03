export interface User {
  id: number;
  email: string;
  full_name: string;
  phone?: string;
  role: 'client' | 'workshop' | 'technician' | 'admin';
  created_at: string;
  updated_at: string;
}

export interface Vehicle {
  id: number;
  user_id: number;
  brand: string;
  model: string;
  year: number;
  plate: string;
  color?: string;
  created_at: string;
  updated_at: string;
}

export interface Workshop {
  id: number;
  owner_id: number;
  name: string;
  address?: string;
  phone?: string;
  latitude?: number;
  longitude?: number;
  commission_percentage?: number;
  commission_rate: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  owner?: User;
}

export interface TenantWorkshop {
  id: number;
  name: string;
  address: string;
  latitude: number;
  longitude: number;
  commission_percentage: number;
  is_active: boolean;
  owner_id: number;
  owner_name: string | null;
  owner_email: string | null;
  owner_phone?: string | null;
  technician_count: number;
  active_technician_count: number;
  created_at?: string;
  updated_at?: string;
}

export interface TenantWorkshopOwnerOption {
  id: number;
  full_name: string;
  email: string;
  phone?: string | null;
  role: string;
  has_workshop: boolean;
  workshop_id?: number | null;
}

export interface TenantWorkshopCreateRequest {
  owner_id: number;
  name: string;
  address: string;
  latitude: number;
  longitude: number;
  commission_percentage: number;
  is_active: boolean;
}

export interface TenantWorkshopOwnerCreateRequest {
  full_name: string;
  email: string;
  phone?: string | null;
  password: string;
}

export interface TenantWorkshopDataCreateRequest {
  name: string;
  address: string;
  latitude: number;
  longitude: number;
  commission_percentage: number;
  is_active: boolean;
}

export interface TenantWorkshopWithOwnerCreateRequest {
  owner: TenantWorkshopOwnerCreateRequest;
  workshop: TenantWorkshopDataCreateRequest;
}

export interface TenantWorkshopUpdateRequest {
  name: string;
  address: string;
  latitude: number;
  longitude: number;
  commission_percentage: number;
  is_active: boolean;
}

export interface TenantWorkshopStatusRequest {
  is_active: boolean;
}

export interface TenantWorkshopUserRow {
  row_type: 'owner' | 'technician';
  relation: string;
  user_id: number | null;
  technician_id: number | null;
  workshop_id: number;
  full_name: string | null;
  email: string | null;
  phone: string | null;
  role: string;
  is_active: boolean;
  is_available: boolean | null;
  access_code: string | null;
}

export interface TenantTechnicianCreateRequest {
  full_name: string;
  email: string;
  password: string;
  phone?: string | null;
  is_active: boolean;
  is_available: boolean;
}

export interface TenantTechnicianUpdateRequest {
  full_name: string;
  phone?: string | null;
  is_active: boolean;
  is_available: boolean;
}

export interface TenantTechnicianStatusRequest {
  is_active: boolean;
}

export interface AdminWorkshopUser {
  user_id?: number;
  full_name?: string;
  email?: string;
  phone?: string;
  role?: 'client' | 'workshop' | 'technician' | 'admin';
  relation: 'owner' | 'technician' | string;
  workshop_id: number;
  technician_id?: number;
  is_active: boolean;
  is_available?: boolean;
  access_code?: string;
}

export interface Technician {
  id: number;
  workshop_id: number;
  user_id?: number;
  name: string;
  phone?: string;
  is_available: boolean;
  current_latitude?: number;
  current_longitude?: number;
  created_at: string;
  updated_at: string;
  access_code?: string;
  access_code_expires_at?: string;
  is_active?: boolean;
}

export interface Incident {
  id: number;
  user_id: number;
  vehicle_id: number;
  workshop_id?: number;
  technician_id?: number;
  description: string;
  status: 'pending' | 'waiting_offers' | 'assigned' | 'accepted' | 'on_route' | 'in_service' | 'in_progress' | 'completed' | 'cancelled';
  priority: 'low' | 'medium' | 'high';
  payment_method?: 'cash' | 'transfer' | 'qr';
  latitude?: number;
  longitude?: number;
  location_text?: string;
  image_url?: string;
  audio_url?: string;
  classification?: string;
  ai_summary?: string;
  estimated_arrival_time?: number;
  accepted_at?: string;
  started_at?: string;
  completed_at?: string;
  created_at: string;
  updated_at: string;
  user?: User;
  vehicle?: Vehicle;
  workshop?: Workshop;
  technician?: Technician;
  payment?: Payment;
  offers?: Offer[];
}

export interface Offer {
  id: number;
  incident_id: number;
  workshop_id: number;
  technician_id?: number;
  amount: number;
  estimated_arrival_time?: number;
  repair_time_minutes?: number;
  diagnosis_cost?: number;
  labor_cost?: number;
  parts_cost?: number;
  transport_cost?: number;
  additional_cost?: number;
  price_explanation?: string;
  notes?: string;
  status: 'pending' | 'accepted' | 'rejected';
  created_at: string;
  updated_at: string;
  workshop?: Workshop;
  technician?: Technician;
}

export interface IncidentHistory {
  id: number;
  incident_id: number;
  status: string;
  changed_by_user_id: number;
  notes?: string;
  timestamp: string;
}

export interface Payment {
  id: number;
  incident_id: number;
  amount: number;
  payment_method: 'cash' | 'transfer' | 'qr';
  commission_percentage: number;
  commission_amount: number;
  workshop_earnings: number;
  is_paid: boolean;
  paid_at?: string;
  payment_type?: string;
  payment_status?: string;
  original_amount_usd?: number;
  exchange_rate_usd_to_bob?: number;
  amount_bob?: number;
  proof_image_url?: string;
  verified_at?: string;
  verified_by_user_id?: number;
  reference_number?: string;
  notes?: string;
  created_at: string;
  updated_at: string;
}

export interface CancellationPaymentPending {
  payment_id: number;
  incident_id: number;
  client_name?: string;
  payment_type: string;
  payment_status: string;
  amount_usd: number;
  amount_bob?: number;
  exchange_rate_usd_to_bob?: number;
  reference_number?: string;
  proof_image_url?: string;
  notes?: string;
  created_at: string;
}

export interface WorkshopPaymentQr {
  workshop_id: number;
  qr_image_url: string;
  updated_at?: string;
}

export interface WorkshopStats {
  workshop_id: number;
  workshop_name: string;
  total_incidents: number;
  accepted_incidents: number;
  in_progress_incidents: number;
  completed_incidents: number;
  total_technicians: number;
  available_technicians: number;
}

export interface AppNotification {
  id: number;
  user_id: number;
  incident_id?: number;
  title: string;
  message: string;
  notification_type: string;
  is_read: boolean;
  created_at: string;
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface LoginResponse {
  access_token: string;
  token_type: string;
}

export interface RegisterRequest {
  email: string;
  password: string;
  full_name: string;
  phone?: string;
  role: 'client' | 'workshop' | 'admin';
}

export interface AuditLog {
  id: number;
  user_id?: number;
  user_email?: string;
  user_full_name?: string;
  user_role?: 'client' | 'workshop' | 'technician' | 'admin';
  event_type: string;
  action: string;
  section?: string;
  endpoint?: string;
  http_method?: string;
  details?: string;
  created_at: string;
}

export interface OperationalReportRequest {
  start_date?: string;
  end_date?: string;
  workshop_id?: number;
  incident_type?: string;
  status?: string;
  technician_id?: number;
  client_id?: number;
  vehicle_id?: number;
  payment_method?: 'cash' | 'transfer' | 'qr';
}

export interface AppliedFilters {
  start_date?: string | null;
  end_date?: string | null;
  workshop_id?: number | null;
  incident_type?: string | null;
  status?: string | null;
  technician_id?: number | null;
  client_id?: number | null;
  vehicle_id?: number | null;
  payment_method?: string | null;
}

export interface OperationalReportSummary {
  total_incidents: number;
  pending: number;
  waiting_offers: number;
  assigned: number;
  accepted: number;
  in_progress: number;
  completed: number;
  cancelled: number;
  total_amount: number;
  total_workshop_earnings: number;
  total_paid: number;
  total_unpaid: number;
}

export interface OperationalReportItem {
  incident_id: number;
  created_at: string;
  updated_at: string;
  completed_at?: string | null;
  status: Incident['status'];
  priority: Incident['priority'];
  classification?: string | null;
  description: string;
  location_text?: string | null;
  client_id: number;
  client_name?: string | null;
  client_email?: string | null;
  vehicle_id?: number | null;
  vehicle_brand?: string | null;
  vehicle_model?: string | null;
  vehicle_plate?: string | null;
  workshop_id?: number | null;
  workshop_name?: string | null;
  technician_id?: number | null;
  technician_name?: string | null;
  payment_id?: number | null;
  payment_amount?: number | null;
  payment_method?: Payment['payment_method'] | null;
  payment_is_paid?: boolean | null;
  commission_amount?: number | null;
  workshop_earnings?: number | null;
}

export interface OperationalReportResponse {
  role_scope: 'admin' | 'workshop' | 'client';
  applied_filters: AppliedFilters;
  summary: OperationalReportSummary;
  items: OperationalReportItem[];
}

export interface VoiceReportParseRequest {
  text: string;
}

export interface VoiceReportParseResponse {
  recognized_text: string;
  filters: OperationalReportRequest;
  action: 'query' | 'pdf' | 'excel' | null;
  warnings: string[];
}
