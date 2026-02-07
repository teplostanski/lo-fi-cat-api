package modules

import (
	"encoding/json"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

type IWS struct {
	Clients []*websocket.Conn
	mu      sync.RWMutex
}

var WS = IWS{}

func (ws *IWS) SaveClient(conn *websocket.Conn) {
	ws.mu.Lock()
	defer ws.mu.Unlock()
	ws.Clients = append(ws.Clients, conn)
}

func (ws *IWS) RemoveClient(conn *websocket.Conn) {
	ws.mu.Lock()
	defer ws.mu.Unlock()
	var clients []*websocket.Conn
	for _, client := range ws.Clients {
		if client != conn {
			clients = append(clients, client)
		}
	}
	ws.Clients = clients
}

func (ws *IWS) SendMusicInfoToTargetClient(conn *websocket.Conn) {
	musicInfoJson, err := json.Marshal(MusicReader.GetMusicInfo())
	if err != nil {
		Logger.Error(err)
		return
	}

	// Устанавливаем deadline для записи (5 секунд)
	err = conn.SetWriteDeadline(time.Now().Add(5 * time.Second))
	if err != nil {
		// Если не удалось установить deadline, удаляем клиента
		ws.RemoveClient(conn)
		return
	}

	// Проверяем соединение перед отправкой
	err = conn.WriteMessage(websocket.TextMessage, musicInfoJson)
	if err != nil {
		// Если соединение закрыто или произошла ошибка, удаляем клиента из списка
		// Не логируем как ошибку - это нормальное поведение при закрытии соединения
		ws.RemoveClient(conn)
		return
	}

	// Сбрасываем deadline после успешной записи
	conn.SetWriteDeadline(time.Time{})
}

func (ws *IWS) SendMusicInfoToAllClient() {
	ws.mu.RLock()
	clients := make([]*websocket.Conn, len(ws.Clients))
	copy(clients, ws.Clients)
	ws.mu.RUnlock()

	for _, client := range clients {
		ws.SendMusicInfoToTargetClient(client)
	}
}
