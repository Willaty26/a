-- Granja: construye y maneja la parte VISUAL del juego (terreno, cerca, nidos, huevos).
-- No decide monedas ni compras: solo dibuja lo que el servidor ya decidió.
-- Cada jugador tiene su propia granja, puesta en una posición distinta del mapa.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local EggConfig = require(ReplicatedStorage.Shared.EggConfig)

local Granja = {}

---------------------------------------------------------------------
-- Medidas de la granja (en studs)
---------------------------------------------------------------------
local MITAD = 50 -- el terreno mide 100 x 100
local MITAD_CERCA = 47 -- la cerca está un poco dentro del borde
local SUELO = 1 -- altura de la parte de arriba del pasto
local Z_NIDOS = -36 -- los nidos van al fondo de la granja
local SEPARACION = 130 -- distancia entre granjas de distintos jugadores

-- Colores
local COLOR_PASTO = Color3.fromRGB(86, 150, 55)
local COLOR_MADERA = Color3.fromRGB(120, 80, 45)
local COLOR_NIDO = Color3.fromRGB(110, 75, 40)
local COLOR_PAJA = Color3.fromRGB(235, 195, 80)

---------------------------------------------------------------------
-- Función auxiliar: crea una parte simple, fija en el aire
---------------------------------------------------------------------
local function crearParte(padre, tamano, cframe, color, material, forma)
	local parte = Instance.new("Part")
	parte.Anchored = true
	parte.Size = tamano
	parte.CFrame = cframe
	parte.Color = color
	parte.Material = material or Enum.Material.SmoothPlastic
	if forma then
		parte.Shape = forma
	end
	parte.TopSurface = Enum.SurfaceType.Smooth
	parte.BottomSurface = Enum.SurfaceType.Smooth
	parte.Parent = padre
	return parte
end

---------------------------------------------------------------------
-- Espacios: cada jugador usa un "slot" distinto del mapa
---------------------------------------------------------------------
local slotsUsados = {}

local function tomarSlot()
	for i = 1, 200 do
		if not slotsUsados[i] then
			slotsUsados[i] = true
			return i
		end
	end
	return 200
end

---------------------------------------------------------------------
-- Construcción de la granja
---------------------------------------------------------------------
local function construirTerreno(modelo, origen)
	crearParte(
		modelo,
		Vector3.new(MITAD * 2, 1, MITAD * 2),
		origen * CFrame.new(0, SUELO - 0.5, 0),
		COLOR_PASTO,
		Enum.Material.Grass
	)
end

local function construirCerca(modelo, origen)
	local lado = MITAD_CERCA * 2
	local pasos = 12
	local separacion = lado / pasos

	-- Postes: uno cada cierta distancia, alrededor de todo el borde
	for k = 0, pasos do
		local p = -MITAD_CERCA + k * separacion
		for _, z in ipairs({ -MITAD_CERCA, MITAD_CERCA }) do
			crearParte(
				modelo,
				Vector3.new(0.8, 4.5, 0.8),
				origen * CFrame.new(p, SUELO + 2.25, z),
				COLOR_MADERA,
				Enum.Material.Wood
			)
		end
		if k > 0 and k < pasos then
			for _, x in ipairs({ -MITAD_CERCA, MITAD_CERCA }) do
				crearParte(
					modelo,
					Vector3.new(0.8, 4.5, 0.8),
					origen * CFrame.new(x, SUELO + 2.25, p),
					COLOR_MADERA,
					Enum.Material.Wood
				)
			end
		end
	end

	-- Travesaños: dos tablas horizontales por cada lado
	for _, altura in ipairs({ 2.0, 3.5 }) do
		for _, z in ipairs({ -MITAD_CERCA, MITAD_CERCA }) do
			crearParte(
				modelo,
				Vector3.new(lado, 0.4, 0.4),
				origen * CFrame.new(0, SUELO + altura, z),
				COLOR_MADERA,
				Enum.Material.Wood
			)
		end
		for _, x in ipairs({ -MITAD_CERCA, MITAD_CERCA }) do
			crearParte(
				modelo,
				Vector3.new(0.4, 0.4, lado),
				origen * CFrame.new(x, SUELO + altura, 0),
				COLOR_MADERA,
				Enum.Material.Wood
			)
		end
	end
end

-- Un nido: disco de barro + paja + palitos alrededor. Devuelve el CFrame de su centro.
local function construirNido(modelo, origen, numero, total)
	-- Los nidos se reparten en una fila, centrados
	local x = (numero - (total + 1) / 2) * 16
	local centro = origen * CFrame.new(x, SUELO, Z_NIDOS)

	-- Los cilindros de Roblox están "acostados"; los giramos 90° para que queden planos
	local plano = CFrame.Angles(0, 0, math.pi / 2)
	crearParte(
		modelo,
		Vector3.new(0.6, 9, 9),
		centro * CFrame.new(0, 0.3, 0) * plano,
		COLOR_NIDO,
		Enum.Material.Wood,
		Enum.PartType.Cylinder
	)
	crearParte(
		modelo,
		Vector3.new(0.4, 7, 7),
		centro * CFrame.new(0, 0.7, 0) * plano,
		COLOR_PAJA,
		Enum.Material.Fabric,
		Enum.PartType.Cylinder
	)

	-- Palitos formando un aro alrededor de la paja
	local cantidadPalitos = 12
	for k = 1, cantidadPalitos do
		local angulo = k / cantidadPalitos * math.pi * 2
		crearParte(
			modelo,
			Vector3.new(0.5, 0.6, 2.4),
			centro * CFrame.new(math.cos(angulo) * 4.3, 1.0, math.sin(angulo) * 4.3) * CFrame.Angles(0, -angulo, 0),
			COLOR_NIDO,
			Enum.Material.Wood
		)
	end

	return centro
end

---------------------------------------------------------------------
-- Crear / destruir la granja de un jugador
---------------------------------------------------------------------
function Granja.Crear(jugador)
	local slot = tomarSlot()
	local origen = CFrame.new((slot - 1) * SEPARACION, 0, 0)

	local modelo = Instance.new("Model")
	modelo.Name = "Granja_" .. jugador.Name

	local granja = {
		Slot = slot,
		Origen = origen,
		Modelo = modelo,
		Nidos = {}, -- Nidos[numero] = CFrame del centro del nido
		Huevos = {}, -- Huevos[numero] = modelo del huevo que está en ese nido
	}

	construirTerreno(modelo, origen)
	construirCerca(modelo, origen)
	local total = EggConfig.MaxHuevosIncubando
	for numero = 1, total do
		granja.Nidos[numero] = construirNido(modelo, origen, numero, total)
	end

	modelo.Parent = workspace
	return granja
end

function Granja.Destruir(granja)
	if not granja then
		return
	end
	slotsUsados[granja.Slot] = nil
	granja.Modelo:Destroy()
end

-- Dónde aparece el jugador: en el frente de su granja, mirando hacia los nidos
function Granja.PuntoAparicion(granja)
	local posicion = granja.Origen * CFrame.new(0, SUELO + 3, 30)
	return CFrame.lookAt(posicion.Position, granja.Origen.Position + Vector3.new(0, SUELO + 3, Z_NIDOS))
end

---------------------------------------------------------------------
-- Huevos
---------------------------------------------------------------------

-- Anima el huevo: cuando falta poco para eclosionar se agita y brilla
local function animarHuevo(modelo, cuerpo, base, termina, color)
	local luz = nil
	local inicio = os.clock()

	while modelo.Parent do
		local restante = termina - os.time()
		if restante <= EggConfig.SegundosAlerta then
			-- Brillo: material neón y una luz que pulsa
			if not luz then
				cuerpo.Material = Enum.Material.Neon
				luz = Instance.new("PointLight")
				luz.Color = color
				luz.Range = 14
				luz.Parent = cuerpo
			end
			local t = os.clock() - inicio
			luz.Brightness = 2 + math.sin(t * 12) * 1.5

			-- Agitado: gira un poco de lado a lado; más fuerte cuanto más cerca de nacer
			local intensidad = 6 + (EggConfig.SegundosAlerta - math.max(restante, 0)) * 3
			local giro = math.rad(math.sin(t * 40) * intensidad)
			cuerpo.CFrame = base * CFrame.Angles(0, 0, giro)
			task.wait(0.03)
		else
			task.wait(0.25)
		end
	end
end

local function crearHuevo(granja, numero, tipo, termina)
	local config = EggConfig.Huevos[tipo]
	if not config then
		return
	end

	local base = granja.Nidos[numero] * CFrame.new(0, 2.8, 0)

	local modelo = Instance.new("Model")
	modelo.Name = "Huevo_" .. numero

	local cuerpo = crearParte(
		modelo,
		Vector3.new(3.4, 4.4, 3.4),
		base,
		config.Color,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	modelo.PrimaryPart = cuerpo

	-- Manchas decorativas, pegadas al cuerpo (soldadas para que se muevan con él)
	local oscuro = config.Color:Lerp(Color3.new(0, 0, 0), 0.35)
	local manchas = {
		{ Vector3.new(0.9, 0.8, -1.35), 0.9 },
		{ Vector3.new(-0.8, -0.6, -1.45), 0.7 },
		{ Vector3.new(0.2, 1.5, -1.0), 0.6 },
	}
	for _, datos in ipairs(manchas) do
		local mancha = crearParte(
			modelo,
			Vector3.new(datos[2], datos[2], datos[2]),
			base * CFrame.new(datos[1]),
			oscuro,
			Enum.Material.SmoothPlastic,
			Enum.PartType.Ball
		)
		mancha.Anchored = false
		mancha.CanCollide = false
		mancha.Massless = true
		local soldadura = Instance.new("WeldConstraint")
		soldadura.Part0 = cuerpo
		soldadura.Part1 = mancha
		soldadura.Parent = cuerpo
	end

	modelo.Parent = granja.Modelo
	granja.Huevos[numero] = modelo

	task.spawn(animarHuevo, modelo, cuerpo, base, termina, config.Color)
end

-- Hace que lo que se ve en la granja coincida con los datos del jugador
function Granja.Sincronizar(granja, datos)
	local presentes = {}
	for _, huevo in ipairs(datos.Huevos) do
		if huevo.Nido then
			presentes[huevo.Nido] = true
		end
		if huevo.Nido and not granja.Huevos[huevo.Nido] then
			crearHuevo(granja, huevo.Nido, huevo.Tipo, huevo.Termina)
		end
	end

	-- Quitamos los huevos de nidos que ya no tienen huevo
	for numero, modelo in pairs(granja.Huevos) do
		if not presentes[numero] then
			modelo:Destroy()
			granja.Huevos[numero] = nil
		end
	end
end

-- Efecto cuando un huevo eclosiona: destellos y se quita el huevo
function Granja.EfectoEclosion(granja, numero)
	local modelo = granja.Huevos[numero]
	if modelo then
		modelo:Destroy()
		granja.Huevos[numero] = nil
	end

	-- Parte invisible que suelta chispas
	local emisor = crearParte(
		granja.Modelo,
		Vector3.new(1, 1, 1),
		granja.Nidos[numero] * CFrame.new(0, 3, 0),
		Color3.new(1, 1, 1)
	)
	emisor.Transparency = 1
	emisor.CanCollide = false

	local chispas = Instance.new("ParticleEmitter")
	chispas.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	chispas.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 140, 60))
	chispas.Size = NumberSequence.new(1.2, 0)
	chispas.Lifetime = NumberRange.new(0.8, 1.4)
	chispas.Speed = NumberRange.new(10, 22)
	chispas.SpreadAngle = Vector2.new(180, 180)
	chispas.LightEmission = 1
	chispas.Rate = 0
	chispas.Parent = emisor
	chispas:Emit(45)

	Debris:AddItem(emisor, 2)
end

return Granja
