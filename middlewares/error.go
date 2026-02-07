package middlewares

import (
	"strings"

	"github.com/labstack/echo/v4"
	"github.com/pxgo/go-fm/modules"
	"github.com/pxgo/go-fm/settings"
	"github.com/pxgo/go-fm/tools"
	"net/http"
)

func CustomHTTPErrorHandler(err error, c echo.Context) {
	// Фильтруем нормальные ошибки закрытия соединений - не логируем их
	errStr := err.Error()
	if strings.Contains(errStr, "broken pipe") ||
		strings.Contains(errStr, "connection has been hijacked") ||
		strings.Contains(errStr, "close 1005") ||
		strings.Contains(errStr, "no status") ||
		strings.Contains(errStr, "websocket: close") {
		// Это нормальное закрытие соединения (WebSocket или HTTP stream)
		// Не логируем и не обрабатываем как ошибку
		return
	}

	var status int
	var resType string
	var message string

	if iErr, ok := err.(tools.IError); ok {
		status = int(iErr.Status)
		resType = string(iErr.Type)
		message = string(iErr.Type)
	} else {
		status = http.StatusInternalServerError
		resType = string(settings.ResponseTypes.ServerInternalError)
		message = err.Error()
	}
	modules.Logger.Error(err)
	err = c.JSON(status, settings.IResponseBody{
		Code:    0,
		Type:    resType,
		Message: message,
	})
	if err != nil {
		// Проверяем, не является ли это ошибкой hijacked connection
		if !strings.Contains(err.Error(), "hijacked") {
			modules.Logger.Error(err)
		}
	}
}
