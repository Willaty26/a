-- Servidor: aquí está toda la lógica del juego.
-- El servidor es el que manda: valida compras, cuenta monedas y guarda datos.
-- El cliente solo pide cosas ("quiero comprar un huevo") y muestra lo que el servidor le dice.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local EggConfig = require(ReplicatedStorage.Shared.EggConfig)
local Granja = require(script.Granja) -- la parte visual (terreno, nidos, huevos)

---------------------------------------------------------------------
-- 1. Remotos (canales de comunicación servidor <-> cliente)
---------------------------------------------------------------------
local carpetaRemotos = Instance.new("Folder")
carpetaRemotos.Name = "Remotos"
carpetaRemotos.Parent = ReplicatedStorage

-- Cliente -> Servidor: "quiero comprar un huevo de este tipo"
local remotoComprar = Instance.new("RemoteEvent")
remotoComprar.Name = "ComprarHuevo"
remotoComprar.Parent = carpetaRemotos

-- Servidor -> Cliente: "estos son tus datos actuales"
local remotoActualizar = Instance.new("RemoteEvent")
remotoActualizar.Name = "ActualizarDatos"
remotoActualizar.Parent = carpetaRemotos

---------------------------------------------------------------------
-- 2. Datos de los jugadores
---------------------------------------------------------------------
-- Si el juego no está publicado (o falta activar la API en Studio), GetDataStore da error.
-- Lo envolvemos en pcall: si falla, el juego funciona igual pero sin guardar.
local okAlmacen, almacen = pcall(function()
	return DataStoreService:GetDataStore(EggConfig.NombreDataStore)
end)
if not okAlmacen then
	warn("DataStore no disponible, el juego NO guardará: " .. tostring(almacen))
	almacen = nil
end

-- datosJugadores[jugador] = { Monedas, Huevos, Criaturas }
--   Huevos:    lista de { Tipo = "Comun", Termina = <os.time() en que nace> }
--   Criaturas: { ["Cuco"] = cantidad, ... }
local datosJugadores = {}

-- Jugadores cuyos datos se cargaron bien del DataStore.
-- Si la carga falló NO guardamos, para no borrar su progreso real.
local puedeGuardar = {}

-- Para limitar las compras (anti-spam)
local ultimaCompra = {}

-- granjas[jugador] = la granja visual de ese jugador (ver Granja.luau)
local granjas = {}

-- Tabla rápida: nombre de criatura -> ingreso por segundo
local ingresoPorCriatura = {}
for _, huevo in pairs(EggConfig.Huevos) do
	for _, criatura in ipairs(huevo.Criaturas) do
		ingresoPorCriatura[criatura.Nombre] = criatura.Ingreso
	end
end

local function datosNuevos()
	return {
		Monedas = EggConfig.MonedasIniciales,
		Huevos = {},
		Criaturas = {},
	}
end

-- Suma el ingreso por segundo de todas las criaturas del jugador
local function calcularIngreso(datos)
	local total = 0
	for nombre, cantidad in pairs(datos.Criaturas) do
		total += (ingresoPorCriatura[nombre] or 0) * cantidad
	end
	return total
end

-- Manda al cliente una "foto" de sus datos para que la dibuje
local function enviarDatos(jugador)
	local datos = datosJugadores[jugador]
	if not datos then
		return
	end

	-- Aprovechamos para que la granja visual coincida con los datos
	local granja = granjas[jugador]
	if granja then
		Granja.Sincronizar(granja, datos)
	end

	-- En vez de la hora absoluta mandamos los segundos que FALTAN,
	-- así el cliente no depende de su propio reloj.
	local huevos = {}
	for _, huevo in ipairs(datos.Huevos) do
		table.insert(huevos, {
			Tipo = huevo.Tipo,
			Restante = math.max(0, huevo.Termina - os.time()),
		})
	end

	remotoActualizar:FireClient(jugador, {
		Monedas = datos.Monedas,
		Ingreso = calcularIngreso(datos),
		Huevos = huevos,
		Criaturas = datos.Criaturas,
	})
end

---------------------------------------------------------------------
-- 3. Guardar y cargar (DataStore)
---------------------------------------------------------------------
local function cargarDatos(jugador)
	-- Sin DataStore jugamos con datos nuevos y no se guarda nada
	if not almacen then
		return datosNuevos()
	end

	local clave = "Jugador_" .. jugador.UserId
	local datos, ok

	-- Probamos hasta 3 veces porque el DataStore a veces falla
	for intento = 1, 3 do
		ok, datos = pcall(function()
			return almacen:GetAsync(clave)
		end)
		if ok then
			break
		end
		warn("No se pudo cargar a " .. jugador.Name .. " (intento " .. intento .. "): " .. tostring(datos))
		task.wait(2)
	end

	if ok then
		puedeGuardar[jugador] = true
		-- datos es nil si el jugador es nuevo
		return datos or datosNuevos()
	end

	-- Falló todo: jugamos con datos temporales y NO guardamos al salir
	warn("Datos temporales para " .. jugador.Name .. " (no se guardará su partida)")
	return datosNuevos()
end

local function guardarDatos(jugador)
	local datos = datosJugadores[jugador]
	if not datos or not puedeGuardar[jugador] then
		return
	end

	local clave = "Jugador_" .. jugador.UserId
	local ok, err = pcall(function()
		almacen:SetAsync(clave, datos)
	end)
	if not ok then
		warn("No se pudo guardar a " .. jugador.Name .. ": " .. tostring(err))
	end
end

---------------------------------------------------------------------
-- 4. Lógica del juego
---------------------------------------------------------------------

-- Elige una criatura al azar según su Peso
local function elegirCriatura(huevoConfig)
	local pesoTotal = 0
	for _, criatura in ipairs(huevoConfig.Criaturas) do
		pesoTotal += criatura.Peso
	end

	local tirada = math.random() * pesoTotal
	for _, criatura in ipairs(huevoConfig.Criaturas) do
		tirada -= criatura.Peso
		if tirada <= 0 then
			return criatura
		end
	end
	-- Por si el redondeo falla, devolvemos la última
	return huevoConfig.Criaturas[#huevoConfig.Criaturas]
end

-- Revisa si algún huevo ya terminó de incubar y hace nacer la criatura
local function revisarIncubacion(jugador, datos)
	-- Recorremos al revés para poder borrar elementos sin problemas
	for i = #datos.Huevos, 1, -1 do
		local huevo = datos.Huevos[i]
		if os.time() >= huevo.Termina then
			local config = EggConfig.Huevos[huevo.Tipo]
			if config then
				local criatura = elegirCriatura(config)
				datos.Criaturas[criatura.Nombre] = (datos.Criaturas[criatura.Nombre] or 0) + 1
			end
			table.remove(datos.Huevos, i)

			-- Efecto visual en el nido (si la granja ya existe)
			local granja = granjas[jugador]
			if granja and huevo.Nido then
				Granja.EfectoEclosion(granja, huevo.Nido)
			end
		end
	end
end

-- Cada huevo vive en un nido (1 a MaxHuevosIncubando).
-- Devuelve el primer nido libre, o nil si todos están ocupados.
local function nidoLibre(datos)
	local ocupados = {}
	for _, huevo in ipairs(datos.Huevos) do
		ocupados[huevo.Nido] = true
	end
	for numero = 1, EggConfig.MaxHuevosIncubando do
		if not ocupados[numero] then
			return numero
		end
	end
	return nil
end

-- Los huevos guardados antes de existir los nidos no tienen número: se los damos
local function asignarNidos(datos)
	local ocupados = {}
	for _, huevo in ipairs(datos.Huevos) do
		if huevo.Nido then
			ocupados[huevo.Nido] = true
		end
	end
	for _, huevo in ipairs(datos.Huevos) do
		if not huevo.Nido then
			for numero = 1, EggConfig.MaxHuevosIncubando do
				if not ocupados[numero] then
					huevo.Nido = numero
					ocupados[numero] = true
					break
				end
			end
		end
	end
end

-- El cliente pidió comprar un huevo: aquí validamos TODO
local function alComprar(jugador, tipo)
	local datos = datosJugadores[jugador]
	if not datos then
		return
	end

	-- El tipo debe ser un texto que exista en EggConfig
	if typeof(tipo) ~= "string" then
		return
	end
	local config = EggConfig.Huevos[tipo]
	if not config then
		return
	end

	-- Anti-spam: máximo una compra cada 0.25 segundos
	local ahora = os.clock()
	if ultimaCompra[jugador] and ahora - ultimaCompra[jugador] < 0.25 then
		return
	end
	ultimaCompra[jugador] = ahora

	-- Debe haber un nido libre y monedas suficientes
	local nido = nidoLibre(datos)
	if not nido then
		return
	end
	if datos.Monedas < config.Precio then
		return
	end

	datos.Monedas -= config.Precio
	table.insert(datos.Huevos, {
		Tipo = tipo,
		Nido = nido,
		Termina = os.time() + config.Incubacion,
	})
	enviarDatos(jugador)
end

remotoComprar.OnServerEvent:Connect(alComprar)

---------------------------------------------------------------------
-- 5. Entrada y salida de jugadores
---------------------------------------------------------------------
-- Pone al personaje del jugador en el frente de su granja
local function llevarAGranja(jugador)
	local granja = granjas[jugador]
	local personaje = jugador.Character
	if granja and personaje and personaje.Parent then
		personaje:PivotTo(Granja.PuntoAparicion(granja))
	end
end

local function alEntrar(jugador)
	-- Cada vez que aparece el personaje (al entrar o al reaparecer) lo llevamos a su granja
	jugador.CharacterAdded:Connect(function(personaje)
		personaje:WaitForChild("HumanoidRootPart")
		llevarAGranja(jugador)
	end)

	local datos = cargarDatos(jugador)
	-- El jugador pudo irse mientras cargaban sus datos
	if jugador.Parent ~= Players then
		return
	end
	datosJugadores[jugador] = datos
	asignarNidos(datos)
	revisarIncubacion(jugador, datos) -- por si algún huevo terminó mientras estaba fuera
	granjas[jugador] = Granja.Crear(jugador)
	llevarAGranja(jugador)
	enviarDatos(jugador)
end

local function alSalir(jugador)
	guardarDatos(jugador)
	Granja.Destruir(granjas[jugador])
	granjas[jugador] = nil
	datosJugadores[jugador] = nil
	puedeGuardar[jugador] = nil
	ultimaCompra[jugador] = nil
end

Players.PlayerAdded:Connect(alEntrar)
Players.PlayerRemoving:Connect(alSalir)

-- Jugadores que ya estaban cuando arrancó este script (pasa en Studio)
for _, jugador in ipairs(Players:GetPlayers()) do
	task.spawn(alEntrar, jugador)
end

-- Al cerrar el servidor, guardamos a todos
game:BindToClose(function()
	for _, jugador in ipairs(Players:GetPlayers()) do
		guardarDatos(jugador)
	end
end)

---------------------------------------------------------------------
-- 6. Bucles: ingreso pasivo (cada segundo) y autoguardado
---------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(1)
		for jugador, datos in pairs(datosJugadores) do
			datos.Monedas += calcularIngreso(datos)
			revisarIncubacion(jugador, datos)
			enviarDatos(jugador)
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(EggConfig.SegundosAutoguardado)
		for _, jugador in ipairs(Players:GetPlayers()) do
			guardarDatos(jugador)
		end
	end
end)
