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
  commission_rate: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  owner?: User;
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
  status: 'pending' | 'waiting_offers' | 'assigned' | 'accepted' | 'in_progress' | 'completed' | 'cancelled';
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
  reference_number?: string;
  notes?: string;
  created_at: string;
  updated_at: string;
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
