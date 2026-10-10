--!strict
-- The fixed overhead camera (client/CameraController.luau).

return table.freeze({
	-- Camera position relative to the character. More Y looks straighter down; more Z tilts it.
	OFFSET = Vector3.new(0, 50, 30),
	FIELD_OF_VIEW = 60,
})
