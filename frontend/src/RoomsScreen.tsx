import { useState } from "react";
import type { Room, User } from "./types";

type Props = {
  rooms: Room[];
  user: User;
  loading: boolean;
  error: string | null;
  onCreateRoom: (name: string) => void;
  onJoin: (room: Room) => void;
  onLogout: () => void;
};

export function RoomsScreen({ rooms, user, loading, error, onCreateRoom, onJoin, onLogout }: Props) {
  const [newRoomName, setNewRoomName] = useState("");

  function handleCreateRoom(e: React.FormEvent) {
    e.preventDefault();
    if (!newRoomName.trim()) return;
    onCreateRoom(newRoomName.trim());
    setNewRoomName("");
  }

  return (
    <div className="rooms-screen">
      <header>
        <h1>ルーム一覧</h1>
        <div className="user-info">
          <span>{user.name} さん</span>
          <button type="button" onClick={onLogout}>
            ログアウト
          </button>
        </div>
      </header>

      <form className="create-room" onSubmit={handleCreateRoom}>
        <input
          value={newRoomName}
          onChange={(e) => setNewRoomName(e.target.value)}
          placeholder="新しいルーム名"
          required
        />
        <button type="submit" disabled={loading}>
          ルーム作成
        </button>
      </form>

      {error && <p className="error">{error}</p>}

      <ul className="room-list">
        {rooms.map((room) => (
          <li key={room.id}>
            <span className="room-name">{room.name}</span>
            <span className="room-meta">参加人数: {room.member_count}</span>
            <button type="button" disabled={loading} onClick={() => onJoin(room)}>
              参加
            </button>
          </li>
        ))}
        {rooms.length === 0 && <li className="empty">ルームがまだありません</li>}
      </ul>
    </div>
  );
}
