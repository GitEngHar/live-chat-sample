import { useState } from "react";
import { loginUser, registerUser, ApiError } from "./api";
import type { User } from "./types";

type Mode = "login" | "register";

export function AuthScreen({ onAuthenticated }: { onAuthenticated: (user: User) => void }) {
  const [mode, setMode] = useState<Mode>("login");
  const [name, setName] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setSubmitting(true);

    try {
      const user = mode === "login" ? await loginUser(name, password) : await registerUser(name, password);
      onAuthenticated(user);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "通信に失敗しました");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="auth-screen">
      <h1>Live Chat Sample</h1>
      <div className="tabs">
        <button type="button" className={mode === "login" ? "active" : ""} onClick={() => setMode("login")}>
          ログイン
        </button>
        <button type="button" className={mode === "register" ? "active" : ""} onClick={() => setMode("register")}>
          ユーザー登録
        </button>
      </div>

      <form onSubmit={handleSubmit}>
        <label>
          ユーザー名
          <input value={name} onChange={(e) => setName(e.target.value)} required autoComplete="username" />
        </label>
        <label>
          パスワード
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            autoComplete={mode === "login" ? "current-password" : "new-password"}
          />
        </label>

        {error && <p className="error">{error}</p>}

        <button type="submit" disabled={submitting}>
          {mode === "login" ? "ログイン" : "登録する"}
        </button>
      </form>
    </div>
  );
}
