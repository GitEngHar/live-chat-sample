import type { Message, Room, User } from "./types";

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? "http://localhost:3000";

class ApiError extends Error {}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${API_BASE_URL}${path}`, { credentials: "include", ...init });
  const body = await res.json().catch(() => null);

  if (!res.ok) {
    const message = body?.errors?.join(", ") ?? `リクエストに失敗しました (status: ${res.status})`;
    throw new ApiError(message);
  }

  return body as T;
}

function toFormBody(params: Record<string, string | number>): string {
  return new URLSearchParams(
    Object.fromEntries(Object.entries(params).map(([key, value]) => [key, String(value)])),
  ).toString();
}

export function registerUser(name: string, password: string): Promise<User> {
  return request<User>("/user/create", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: toFormBody({ name, password }),
  });
}

export function loginUser(name: string, password: string): Promise<User> {
  const query = new URLSearchParams({ name, password }).toString();
  return request<User>(`/user/get?${query}`);
}

export function fetchRooms(userId: number): Promise<Room[]> {
  const query = new URLSearchParams({ user_id: String(userId) }).toString();
  return request<Room[]>(`/room/index?${query}`);
}

export function createRoom(name: string, userId: number): Promise<Room> {
  return request<Room>("/room/create", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: toFormBody({ name, user_id: userId }),
  });
}

export function updateRoomMembership(
  roomId: number,
  userId: number,
  actionType: "join" | "leave",
): Promise<Room> {
  return request<Room>("/room/action", {
    method: "PUT",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: toFormBody({ room_id: roomId, user_id: userId, action_type: actionType }),
  });
}

export function fetchMessages(roomId: number): Promise<Message[]> {
  const query = new URLSearchParams({ room_id: String(roomId) }).toString();
  return request<Message[]>(`/chat/streams/index?${query}`);
}

export function sendMessage(roomId: number, userId: number, content: string): Promise<Message> {
  return request<Message>("/chat/streams/create", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: toFormBody({ room_id: roomId, user_id: userId, content }),
  });
}

export { ApiError };
