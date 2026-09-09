import { useEffect, useState } from "react";
import { connectCable, subscribeToChannel, unsubscribeFromChannel } from "./cable";
import { fetchMessages, sendMessage, ApiError } from "./api";
import type { Message, Room, User } from "./types";

type Props = {
  room: Room;
  user: User;
  loading: boolean;
  error: string | null;
  onLeave: () => void;
};

export function ChatScreen({ room, user, loading, error, onLeave }: Props) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [draft, setDraft] = useState("");
  const [sendError, setSendError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    fetchMessages(room.id)
      .then((history) => {
        if (!cancelled) setMessages(history);
      })
      .catch(() => {
        if (!cancelled) setSendError("メッセージ履歴の取得に失敗しました");
      });

    connectCable();
    const subscription = subscribeToChannel<Message>("ChatChannel", { room_id: room.id }, (message) => {
      setMessages((prev) => (prev.some((m) => m.id === message.id) ? prev : [...prev, message]));
    });

    return () => {
      cancelled = true;
      unsubscribeFromChannel(subscription);
    };
  }, [room.id]);

  async function handleSend(e: React.FormEvent) {
    e.preventDefault();
    if (!draft.trim()) return;

    setSendError(null);
    try {
      await sendMessage(room.id, user.id, draft.trim());
      setDraft("");
    } catch (err) {
      setSendError(err instanceof ApiError ? err.message : "メッセージの送信に失敗しました");
    }
  }

  return (
    <div className="chat-screen">
      <header>
        <div>
          <h1>{room.name}</h1>
        </div>
        <button type="button" disabled={loading} onClick={onLeave}>
          退出
        </button>
      </header>

      {error && <p className="error">{error}</p>}
      {sendError && <p className="error">{sendError}</p>}

      <ul className="message-list">
        {messages.map((message) => (
          <li key={message.id} className={message.sender === user.name ? "mine" : ""}>
            <span className="sender">{message.sender}</span>
            <span className="content">{message.content}</span>
          </li>
        ))}
        {messages.length === 0 && <li className="empty">まだメッセージはありません</li>}
      </ul>

      <form className="message-form" onSubmit={handleSend}>
        <input value={draft} onChange={(e) => setDraft(e.target.value)} placeholder="メッセージを入力" />
        <button type="submit">送信</button>
      </form>
    </div>
  );
}
