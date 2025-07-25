include("shared.lua")

ENT.RenderGroup = RENDERGROUP_BOTH

local render = render
local IsValid = FindMetaTable("Entity").IsValid

surface.CreateFont("Starfall_ErrorFont", {
	font = "arial",
	size = 26,
	weight = 200,
})

function ENT:Initialize()
	self.BaseClass.Initialize(self)

	net.Start("starfall_processor_link")
	net.WriteUInt(self:EntIndex(), 16)
	net.SendToServer()

	self.Transform = {
		lastUpdate = 0,
		get = function(self)
			if CurTime() > self.lastUpdate then
				self.lastUpdate = CurTime()
				self.matrixinv = self.matrix:GetInverseTR()
			end
			return self.matrix, self.matrixinv
		end,
	}

	local info = self.Monitor_Offsets[self:GetModel()]
	if not info then
		local mins = self:OBBMins()
		local maxs = self:OBBMaxs()
		local size = maxs - mins
		info = {
			Name = "",
			RS = (size.y - 1) / 512,
			RatioX = size.y / size.x,
			offset = self:OBBCenter() + Vector(0, 0, maxs.z - 0.24),
			rot = Angle(0, 0, 180),
			x1 = 0,
			x2 = 0,
			y1 = 0,
			y2 = 0,
			z = 0,
		}
	end

	self.ScreenInfo = info
	self:SetScreenMatrix(info)
end

function ENT:SetScreenMatrix(info)
	local rotation, translation, translation2, scale = Matrix(), Matrix(), Matrix(), Matrix()
	rotation:SetAngles(info.rot)
	translation:SetTranslation(info.offset)
	translation2:SetTranslation(Vector(-256 / info.RatioX, -256, 0))
	scale:SetScale(Vector(info.RS, info.RS, info.RS))

	self.ScreenMatrix = translation * rotation * scale * translation2
	self.Aspect = info.RatioX
	self.Scale = info.RS
	self.Origin = info.offset
	self.Transform.matrix = self:GetWorldTransformMatrix() * self.ScreenMatrix

	local w, h = 512 / self.Aspect, 512
	self.ScreenQuad = { Vector(0, 0, 0), Vector(w, 0, 0), Vector(w, h, 0), Vector(0, h, 0), Color(0, 0, 0, 255) }
end

function ENT:RenderScreen()
	if IsValid(self.link) then
		local instance = self.link.instance
		if instance then
			if SF.Permissions.hasAccess(instance, nil, "render.screen") then
				local renderdata = instance.data.render
				local prevEnt = renderdata.renderEnt
				local prevnoStencil = renderdata.noStencil

				renderdata.renderEnt = self
				renderdata.noStencil = true
				instance:prepareRender()
				instance:runScriptHook("render")
				instance:cleanupRender()
				renderdata.renderEnt = prevEnt
				renderdata.noStencil = prevnoStencil
			end
		elseif self.link.error then
			local error = self.link.error
			if not error.markup then
				local msg = error.message or ""
				local location = (error.file and error.line) and ("File: " .. error.file .. "\nLine: " .. error.line)
					or ""
				msg = msg:sub(1, 512)
				error.markup = markup.Parse(
					"<font=Starfall_ErrorFont><colour=0, 255, 255, 255>Error occurred in Neostarfall:\n</colour><color=255, 0, 0, 255>"
						.. msg
						.. "\n</color><color=255, 255, 255, 255>"
						.. location
						.. "</color></font>",
					512
				)
			end
			surface.SetTexture(0)
			surface.SetDrawColor(0, 0, 0, 255)
			surface.DrawRect(0, 0, 512, 512)
			error.markup:Draw(0, 0, 0, 3)
		end
	end
end

function ENT:Draw()
	self:DrawModel()
end

function ENT:SetBackgroundColor(r, g, b, a)
	self.ScreenQuad[5] = Color(r, g, b, math.max(a, 1))
end

local VECTOR_1_1_1 = Vector(1, 1, 1)
local writez = Material("engine/writez")
function ENT:DrawTranslucent()
	self:DrawModel()

	if halo.RenderedEntity() == self then
		return
	end

	local transform = self:GetWorldTransformMatrix() * self.ScreenMatrix
	self.Transform.matrix = transform

	cam.PushModelMatrix(transform)
	render.ClearStencil()
	render.SetStencilEnable(true)
	render.SetStencilFailOperation(STENCILOPERATION_KEEP)
	render.SetStencilZFailOperation(STENCILOPERATION_KEEP)
	render.SetStencilPassOperation(STENCILOPERATION_REPLACE)
	render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_ALWAYS)
	render.SetStencilWriteMask(1)
	render.SetStencilReferenceValue(1)

	--First draw a quad that defines the visible area
	render.SetColorMaterial()
	render.DrawQuad(unpack(self.ScreenQuad))

	render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
	render.SetStencilTestMask(1)

	local tone = render.GetToneMappingScaleLinear()
	render.SetToneMappingScaleLinear(VECTOR_1_1_1)

	--Clear it to the clear color and clear depth as well
	local color = self.ScreenQuad[5]
	if color.a == 255 then
		render.ClearBuffersObeyStencil(color.r, color.g, color.b, color.a, true)
	end

	--Render the starfall stuff
	render.PushFilterMag(TEXFILTER.ANISOTROPIC)
	render.PushFilterMin(TEXFILTER.ANISOTROPIC)

	self:RenderScreen()

	render.PopFilterMag()
	render.PopFilterMin()

	render.SetToneMappingScaleLinear(tone)

	render.SetStencilEnable(false)

	--Give the screen back its depth
	render.SetMaterial(writez)
	render.DrawQuad(unpack(self.ScreenQuad))

	cam.PopModelMatrix()
end

function ENT:GetResolution()
	return 512 / self.Aspect, 512
end

ENT.Monitor_Offsets = {
	["models/hunter/blocks/cube1x1x1.mdl"] = {
		Name = "Cube 1 (1:1)",
		RS = 0.09,
		RatioX = 1,
		offset = Vector(24, 0, 0),
		rot = Angle(0, 90, -90),
		x1 = -48,
		x2 = 48,
		y1 = -48,
		y2 = 48,
		z = 24,
	},
	["models/hunter/plates/plate05x05.mdl"] = {
		Name = "Panel 0.5 (1:1)",
		RS = 0.045,
		RatioX = 1,
		offset = Vector(0, 0, 1.7),
		rot = Angle(0, 90, 180),
		x1 = -48,
		x2 = 48,
		y1 = -48,
		y2 = 48,
		z = 0,
	},
	["models/hunter/plates/plate1x1.mdl"] = {
		Name = "Panel 1 (1:1)",
		RS = 0.09,
		RatioX = 1,
		offset = Vector(0, 0, 2),
		rot = Angle(0, 90, 180),
		x1 = -48,
		x2 = 48,
		y1 = -48,
		y2 = 48,
		z = 0,
	},
	["models/hunter/plates/plate2x2.mdl"] = {
		Name = "Panel 2 (1:1)",
		RS = 0.182,
		RatioX = 1,
		offset = Vector(0, 0, 2),
		rot = Angle(0, 90, 180),
		x1 = -48,
		x2 = 48,
		y1 = -48,
		y2 = 48,
		z = 0,
	},
	["models/hunter/plates/plate4x4.mdl"] = {
		Name = "Panel 4 (1:1)",
		RS = 0.3707,
		RatioX = 1,
		offset = Vector(0, 0, 2),
		rot = Angle(0, 90, 180),
		x1 = -94.9,
		x2 = 94.9,
		y1 = -94.9,
		y2 = 94.9,
		z = 1.7,
	},
	["models/hunter/plates/plate8x8.mdl"] = {
		Name = "Panel 8 (1:1)",
		RS = 0.741,
		RatioX = 1,
		offset = Vector(0, 0, 2),
		rot = Angle(0, 90, 180),
		x1 = -189.8,
		x2 = 189.8,
		y1 = -189.8,
		y2 = 189.8,
		z = 1.7,
	},
	["models/hunter/plates/plate16x16.mdl"] = {
		Name = "Panel 16 (1:1)",
		RS = 1.482,
		RatioX = 1,
		offset = Vector(0, 0, 2),
		rot = Angle(0, 90, 180),
		x1 = -379.6,
		x2 = 379.6,
		y1 = -379.6,
		y2 = 379.6,
		z = 1.7,
	},
	["models/hunter/plates/plate24x24.mdl"] = {
		Name = "Panel 24 (1:1)",
		RS = 2.223,
		RatioX = 1,
		offset = Vector(0, 0, 2),
		rot = Angle(0, 90, 180),
		x1 = -569.4,
		x2 = 569.4,
		y1 = -569.4,
		y2 = 569.4,
		z = 1.7,
	},
	["models/hunter/plates/plate32x32.mdl"] = {
		Name = "Panel 32 (1:1)",
		RS = 2.964,
		RatioX = 1,
		offset = Vector(0, 0, 2),
		rot = Angle(0, 90, 180),
		x1 = -759.2,
		x2 = 759.2,
		y1 = -759.2,
		y2 = 759.2,
		z = 1.7,
	},
	["models/props/cs_assault/billboard.mdl"] = {
		Name = "Billboard",
		RS = 0.23,
		RatioX = 0.522,
		offset = Vector(2, 0, 0),
		rot = Angle(0, 90, -90),
		x1 = -110.512,
		x2 = 110.512,
		y1 = -57.647,
		y2 = 57.647,
		z = 1,
	},
	["models/props/cs_office/computer_monitor.mdl"] = {
		Name = "LCD Monitor (4:3)",
		RS = 0.031,
		RatioX = 0.767,
		offset = Vector(3.3, 0, 16.7),
		rot = Angle(0, 90, -90),
		x1 = -10.5,
		x2 = 10.5,
		y1 = 8.6,
		y2 = 24.7,
		z = 3.3,
	},
	["models/props/cs_office/tv_plasma.mdl"] = {
		Name = "Plasma TV (16:10)",
		RS = 0.065,
		RatioX = 0.5965,
		offset = Vector(6.1, 0, 18.93),
		rot = Angle(0, 90, -90),
		x1 = -28.5,
		x2 = 28.5,
		y1 = 2,
		y2 = 36,
		z = 6.1,
	},
	["models/props_lab/monitor01b.mdl"] = {
		Name = "Small TV (1:1)",
		RS = 0.0185,
		RatioX = 1.0173,
		offset = Vector(6.53, -1, 0.45),
		rot = Angle(0, 90, -90),
		x1 = -5.535,
		x2 = 3.5,
		y1 = -4.1,
		y2 = 5.091,
		z = 6.53,
	},
	["models/props_lab/workspace002.mdl"] = {
		Name = "Workspace (1:1)",
		RS = 0.06836,
		RatioX = 0.9669,
		offset = Vector(-42.133224, -42.372322, 42.110897),
		rot = Angle(0, 133.340, -120.317),
		x1 = -18.1,
		x2 = 18.1,
		y1 = -17.5,
		y2 = 17.5,
		z = 42.1109,
	},
	["models/props_mining/billboard001.mdl"] = {
		Name = "TF2 Red billboard (7:4)",
		RS = 0.375,
		RatioX = 0.5714,
		offset = Vector(3.5, 0, 96),
		rot = Angle(0, 90, -90),
		x1 = -168,
		x2 = 168,
		y1 = -96,
		y2 = 96,
		z = 96,
	},
	["models/props_mining/billboard002.mdl"] = {
		Name = "TF2 Red vs Blue billboard (51:16)",
		RS = 0.375,
		RatioX = 0.3137,
		offset = Vector(3.5, 0, 192),
		rot = Angle(0, 90, -90),
		x1 = -306,
		x2 = 306,
		y1 = -96,
		y2 = 96,
		z = 192,
	},

	["models/hunter/plates/plate075x1.mdl"] = {
		Name = "Plate (0.75x1)",
		RS = 0.07,
		RatioX = 0.76,
		offset = Vector(-5.9, 0, 1.65),
		rot = Angle(0, 90, 180),
		x1 = -23.5,
		y1 = -18,
		x2 = 23.5,
		y2 = 18,
		z = 0.5,
	},
	["models/hunter/plates/plate2x3.mdl"] = {
		Name = "Plate (2x3)",
		RS = 0.185,
		RatioX = 0.67,
		offset = Vector(0, 0, 1.65),
		rot = Angle(0, 90, 180),
		x1 = -70.5,
		y1 = -47.5,
		x2 = 70.5,
		y2 = 47.5,
		z = 0.5,
	},
	["models/hunter/plates/plate3x5.mdl"] = {
		Name = "Plate (3x5)",
		RS = 0.277,
		RatioX = 0.598,
		offset = Vector(0, 0, 1.65),
		rot = Angle(0, 90, 180),
		x1 = -118.5,
		y1 = -71,
		x2 = 118.5,
		y2 = 71,
		z = 0.5,
	},
	["models/hunter/plates/plate4x6.mdl"] = {
		Name = "Plate (4x6)",
		RS = 0.37,
		RatioX = 0.666,
		offset = Vector(0, 0, 1.65),
		rot = Angle(0, 90, 180),
		x1 = -142,
		y1 = -94.5,
		x2 = 142,
		y2 = 94.5,
		z = 0.5,
	},
	["models/hunter/plates/plate5x8.mdl"] = {
		Name = "Plate (5x8)",
		RS = 0.463,
		RatioX = 0.626,
		offset = Vector(0, 0, 1.65),
		rot = Angle(0, 90, 180),
		x1 = -189,
		y1 = -118.3,
		x2 = 189,
		y2 = 118.3,
		z = 0.5,
	},
	["models/hunter/plates/plate6x8.mdl"] = {
		Name = "Plate (6x8)",
		RS = 0.555,
		RatioX = 0.75,
		offset = Vector(0, 0, 1.65),
		rot = Angle(0, 90, 180),
		x1 = -189.3,
		y1 = -142,
		x2 = 189.3,
		y2 = 142,
		z = 0.5,
	},
	["models/hunter/plates/plate16x24.mdl"] = {
		Name = "Plate (16x24)",
		RS = 1.482,
		RatioX = 0.666,
		offset = Vector(0, 0, 2),
		rot = Angle(0, 90, 180),
		x1 = -569.5,
		y1 = -379,
		x2 = 569.5,
		y2 = 379,
		z = 0.5,
	},
}

SF.CustomScreenInfo = {
	Name = "Custom Screen",
	RS = 2,
	RatioX = 1,
	offset = Vector(0, 0, 10),
	rot = Angle(0, 90, 180),
	x1 = -512,
	x2 = 512,
	y1 = -512,
	y2 = 512,
	z = 0,
}

ENT.Monitor_Offsets["models/maxofs2d/hover_plate.mdl"] = SF.CustomScreenInfo
