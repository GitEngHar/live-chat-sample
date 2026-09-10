export type User = {
  id: number;
  name: string;
};

export type Room = {
  id: number;
  name: string;
  owner_id: number;
  member_count: number;
  joined: boolean;
};

export type Message = {
  id: number;
  room_id: number;
  user_id: number;
  sender: string;
  content: string;
  created_at: string;
};

export type PresenceInfo = {
  name: string;
  room_id: number;
};
