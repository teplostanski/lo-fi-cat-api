package main

import (
	"fmt"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	"github.com/pxgo/go-fm/middlewares"
	"github.com/pxgo/go-fm/modules"
	"github.com/pxgo/go-fm/routes"
)

func main() {

	modules.InitReader()

	e := echo.New()

	e.HideBanner = true
	e.HTTPErrorHandler = middlewares.CustomHTTPErrorHandler
	e.Use(middlewares.LoggerIn)

	// Настройка CORS для работы с отдельным фронтендом
	e.Use(middleware.CORSWithConfig(middleware.CORSConfig{
		AllowOrigins:     []string{"*"}, // В продакшене укажите конкретные домены
		AllowMethods:     []string{echo.GET, echo.POST, echo.PUT, echo.DELETE, echo.OPTIONS},
		AllowHeaders:     []string{echo.HeaderOrigin, echo.HeaderContentType, echo.HeaderAccept, echo.HeaderAuthorization},
		ExposeHeaders:    []string{echo.HeaderContentLength},
		AllowCredentials: true,
	}))

	// Инициализация API роутов
	routes.InitRoutes(e)

	err := e.Start(fmt.Sprintf("%s:%d", modules.Config.Host, modules.Config.Port))
	if err != nil {
		modules.Logger.Error(err)
	}
}
