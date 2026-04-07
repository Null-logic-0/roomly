# 👥 **Roomly**

[![Elixir](https://img.shields.io/badge/Elixir-1.15-%236C2BD9?style=flat&logo=elixir&logoColor=white)](https://elixir-lang.org/) [![Phoenix](https://img.shields.io/badge/Phoenix-1.8.5-%23F97316?style=flat&logo=phoenix-framework&logoColor=white)](https://www.phoenixframework.org/) [![LiveView](https://img.shields.io/badge/LiveView-1.1.0-%236C2BD9?style=flat&logo=phoenix-framework&logoColor=white)](https://hexdocs.pm/phoenix_live_view/) [![PostgreSQL](https://img.shields.io/badge/PostgreSQL-18-%23336791?style=flat&logo=postgresql&logoColor=white)](https://www.postgresql.org/)

Roomly is a lightweight, real-time video meeting app built with Phoenix LiveView and WebRTC.
It focuses on simplicity—no installs, no friction, just instant rooms you can join and start talking.


---

# 🚀  **Features**

- 🏠 Create Meeting Rooms
- Instantly create a room and share a link.
🔗 Join via Link
- No signup required—just open the link and join.
- 🎥 Real-Time Video & Audio
Peer-to-peer communication powered by WebRTC.
- 👥 Participant List
See who’s in the room in real time using Phoenix Presence.
- 🎙️ Mute / Unmute
Control your microphone during the call.
- 💬 Chat
Send messages to everyone in the room instantly.

---

# 🏗️ **Tech Stack**

- Backend: Elixir + Phoenix + LiveView
- Realtime: Phoenix PubSub + Presence
- Frontend: LiveView + JavaScript Hooks
- Media: WebRTC (P2P)
- Database: PostgreSQL

---

# ⚡ **How It Works**

Roomly uses Phoenix LiveView for real-time UI updates and WebRTC for peer-to-peer media streaming.

- LiveView manages UI state and interactions
- Phoenix Channels / PubSub handle signaling
- WebRTC handles video/audio streams directly between peers

--- 

# 🛠️ **Getting Started**

```bash 
    mix deps.get
    mix ecto.setup
    mix phx.server
```

##### Visit: **http://localhost:4000** 

---

# 📄 **License**

Roomly is open-source software licensed under the **MIT License**.

Feel free to use it for personal or commercial projects. See the 
<a href="/LICENSE">
  **LICENSE**
</a>

file for more information.
