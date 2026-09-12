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
  type: "message";
  id: number;
  room_id: number;
  user_id: number;
  sender: string;
  content: string;
  created_at: string;
};

// ユーザー個人宛の通知(残高警告など)。ChatChannelの個人向けstream
// (stream_for current_user) 経由で届く。ルームのメッセージとは無関係。
export type BalanceWarning = {
  type: "balance_warning";
  content: string;
};

// メッセージフィルタでNGワードと判定され、broadcastされなかった場合の警告。
// 送信者本人にのみ届く。
export type BroadcastWarning = {
  type: "broadcast_warning";
  content: string;
};

export type ChannelPayload = Message | BalanceWarning | BroadcastWarning;

export type PresenceInfo = {
  name: string;
  room_id: number;
};
