import { useEffect, useState } from "react";
import { disconnectCable } from "./cable";
import { createRoom, fetchRooms, updateRoomMembership, ApiError } from "./api";
import { RoomsScreen } from "./RoomsScreen";
import { ChatScreen } from "./ChatScreen";
import type { Room, User } from "./types";

export function Main({ user, onLogout }: { user: User; onLogout: () => void }) {
  const [rooms, setRooms] = useState<Room[]>([]);
  const [activeRoom, setActiveRoom] = useState<Room | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [loaded, setLoaded] = useState(false);

  async function loadRooms() {
    try {
      setError(null);
      const data = await fetchRooms(user.id);
      setRooms(data);
      setActiveRoom(data.find((room) => room.joined) ?? null);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "ルーム一覧の取得に失敗しました");
    } finally {
      setLoaded(true);
    }
  }

  useEffect(() => {
    loadRooms();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user.id]);

  async function handleCreateRoom(name: string) {
    setLoading(true);
    setError(null);
    try {
      const room = await createRoom(name, user.id);
      setActiveRoom(room);
      await loadRooms();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "ルーム作成に失敗しました");
    } finally {
      setLoading(false);
    }
  }

  async function handleJoin(room: Room) {
    setLoading(true);
    setError(null);
    try {
      const joinedRoom = await updateRoomMembership(room.id, user.id, "join");
      setActiveRoom(joinedRoom);
      await loadRooms();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "参加に失敗しました");
    } finally {
      setLoading(false);
    }
  }

  async function handleLeave() {
    if (!activeRoom) return;

    setLoading(true);
    setError(null);
    try {
      await updateRoomMembership(activeRoom.id, user.id, "leave");
      disconnectCable();
      setActiveRoom(null);
      await loadRooms();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "退出に失敗しました");
    } finally {
      setLoading(false);
    }
  }

  if (!loaded) {
    return <p className="loading">読み込み中...</p>;
  }

  if (activeRoom) {
    return <ChatScreen room={activeRoom} user={user} loading={loading} error={error} onLeave={handleLeave} />;
  }

  return (
    <RoomsScreen
      rooms={rooms}
      user={user}
      loading={loading}
      error={error}
      onCreateRoom={handleCreateRoom}
      onJoin={handleJoin}
      onLogout={onLogout}
    />
  );
}
