package routes

import (
	"strings"

	"github.com/gorilla/websocket"
	"github.com/labstack/echo/v4"
	"github.com/pxgo/go-fm/modules"
	"net/http"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

func HandleWS(ctx echo.Context) error {
	conn, err := upgrader.Upgrade(ctx.Response(), ctx.Request(), nil)
	if err != nil {
		modules.Logger.Error(err)
		return err
	}

	// После Upgrade соединение "захвачено", не возвращаем ошибки через Echo
	defer func() {
		modules.WS.RemoveClient(conn)
		conn.Close()
	}()

	modules.WS.SaveClient(conn)
	
	// Отправляем информацию о музыке (может не получиться, если соединение уже закрыто)
	modules.WS.SendMusicInfoToTargetClient(conn)

	for {
		_, _, err := conn.ReadMessage()
		if err != nil {
			// Проверяем все типы нормального закрытия
			if websocket.IsCloseError(err, 
				websocket.CloseNormalClosure,
				websocket.CloseGoingAway,
				websocket.CloseAbnormalClosure,
				websocket.CloseNoStatusReceived) {
				// Нормальное закрытие соединения - не логируем
				break
			}
			// Проверяем, не является ли это закрытием без статуса (1005)
			// Это нормальное поведение браузера при закрытии соединения
			if websocket.IsUnexpectedCloseError(err, websocket.CloseNoStatusReceived) {
				// Это нормально, не логируем
				break
			}
			// Проверяем строку ошибки на наличие "broken pipe" или "close 1005"
			errStr := err.Error()
			if strings.Contains(errStr, "broken pipe") || 
			   strings.Contains(errStr, "close 1005") ||
			   strings.Contains(errStr, "no status") {
				// Это нормальное закрытие, не логируем
				break
			}
			// Только реальные ошибки логируем
			modules.Logger.Error(err)
			break
		}
	}
	return nil
}
