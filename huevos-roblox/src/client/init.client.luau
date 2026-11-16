-- Cliente: solo dibuja la interfaz y le PIDE cosas al servidor.
-- Nunca decide monedas ni compras; eso lo valida el servidor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggConfig = require(ReplicatedStorage.Shared.EggConfig)
local remotos = ReplicatedStorage:WaitForChild("Remotos")
local remotoComprar = remotos:WaitForChild("ComprarHuevo")
local remotoActualizar = remotos:WaitForChild("ActualizarDatos")

local jugador = Players.LocalPlayer
local pantalla = Instance.new("ScreenGui")
pantalla.Name = "InterfazHuevos"
pantalla.ResetOnSpawn = false
pantalla.Parent = jugador:WaitForChild("PlayerGui")

---------------------------------------------------------------------
-- Función auxiliar: crea una etiqueta de texto
---------------------------------------------------------------------
local function crearEtiqueta(nombre, posicion, tamano)
	local etiqueta = Instance.new("TextLabel")
	etiqueta.Name = nombre
	etiqueta.Position = posicion
	etiqueta.Size = tamano
	etiqueta.BackgroundTransparency = 0.3
	etiqueta.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	etiqueta.TextColor3 = Color3.new(1, 1, 1)
	etiqueta.TextScaled = true
	etiqueta.Font = Enum.Font.GothamBold
	etiqueta.TextXAlignment = Enum.TextXAlignment.Left
	etiqueta.Parent = pantalla
	return etiqueta
end

local etiquetaMonedas = crearEtiqueta("Monedas", UDim2.new(0, 10, 0, 10), UDim2.new(0, 260, 0, 40))
local etiquetaIngreso = crearEtiqueta("Ingreso", UDim2.new(0, 10, 0, 55), UDim2.new(0, 260, 0, 30))
local etiquetaHuevos = crearEtiqueta("Huevos", UDim2.new(0, 10, 0, 90), UDim2.new(0, 260, 0, 120))
local etiquetaCriaturas = crearEtiqueta("Criaturas", UDim2.new(0, 10, 0, 215), UDim2.new(0, 260, 0, 140))
etiquetaHuevos.TextYAlignment = Enum.TextYAlignment.Top
etiquetaCriaturas.TextYAlignment = Enum.TextYAlignment.Top
etiquetaHuevos.TextScaled = false
etiquetaHuevos.TextSize = 18
etiquetaCriaturas.TextScaled = false
etiquetaCriaturas.TextSize = 18

---------------------------------------------------------------------
-- Un botón por cada tipo de huevo de EggConfig.Orden
---------------------------------------------------------------------
local contenedorBotones = Instance.new("Frame")
contenedorBotones.Name = "Botones"
contenedorBotones.AnchorPoint = Vector2.new(0.5, 1)
contenedorBotones.Position = UDim2.new(0.5, 0, 1, -20)
contenedorBotones.Size = UDim2.new(0, 560, 0, 70)
contenedorBotones.BackgroundTransparency = 1
contenedorBotones.Parent = pantalla

local disposicion = Instance.new("UIListLayout")
disposicion.FillDirection = Enum.FillDirection.Horizontal
disposicion.HorizontalAlignment = Enum.HorizontalAlignment.Center
disposicion.Padding = UDim.new(0, 10)
disposicion.Parent = contenedorBotones

for _, tipo in ipairs(EggConfig.Orden) do
	local config = EggConfig.Huevos[tipo]
	local boton = Instance.new("TextButton")
	boton.Name = "Comprar_" .. tipo
	boton.Size = UDim2.new(0, 170, 1, 0)
	boton.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
	boton.TextColor3 = Color3.new(1, 1, 1)
	boton.Font = Enum.Font.GothamBold
	boton.TextSize = 18
	boton.Text = config.Nombre .. "\n$" .. config.Precio .. " · " .. config.Incubacion .. "s"
	boton.Parent = contenedorBotones

	-- Solo pedimos la compra; el servidor decide si se puede
	boton.Activated:Connect(function()
		remotoComprar:FireServer(tipo)
	end)
end

---------------------------------------------------------------------
-- Cuando el servidor manda datos, actualizamos los textos
---------------------------------------------------------------------
remotoActualizar.OnClientEvent:Connect(function(datos)
	etiquetaMonedas.Text = " Monedas: " .. datos.Monedas
	etiquetaIngreso.Text = " Ingreso: +" .. datos.Ingreso .. "/s"

	-- Huevos incubando
	local lineas = { " Incubando (" .. #datos.Huevos .. "/" .. EggConfig.MaxHuevosIncubando .. "):" }
	for _, huevo in ipairs(datos.Huevos) do
		local config = EggConfig.Huevos[huevo.Tipo]
		local nombre = if config then config.Nombre else huevo.Tipo
		table.insert(lineas, " " .. nombre .. " - " .. huevo.Restante .. "s")
	end
	etiquetaHuevos.Text = table.concat(lineas, "\n")

	-- Criaturas que ya nacieron
	local criaturas = { " Criaturas:" }
	for nombre, cantidad in pairs(datos.Criaturas) do
		table.insert(criaturas, " " .. nombre .. " x" .. cantidad)
	end
	etiquetaCriaturas.Text = table.concat(criaturas, "\n")
end)
